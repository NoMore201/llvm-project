//===-- CommandObjectDWIMPrint.cpp ------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "CommandObjectDWIMPrint.h"

#include "lldb/DataFormatters/DumpValueObjectOptions.h"
#include "lldb/Expression/ExpressionVariable.h"
#include "lldb/Expression/UserExpression.h"
#include "lldb/Interpreter/CommandInterpreter.h"
#include "lldb/Interpreter/CommandObject.h"
#include "lldb/Interpreter/CommandReturnObject.h"
#include "lldb/Interpreter/OptionGroupFormat.h"
#include "lldb/Interpreter/OptionGroupValueObjectDisplay.h"
#include "lldb/Target/StackFrame.h"
#include "lldb/Utility/ConstString.h"
#include "lldb/Utility/LLDBLog.h"
#include "lldb/Utility/Log.h"
#include "lldb/ValueObject/ValueObject.h"
#include "lldb/lldb-defines.h"
#include "lldb/lldb-enumerations.h"
#include "lldb/lldb-forward.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Support/Error.h"

#include <regex>

using namespace llvm;
using namespace lldb;
using namespace lldb_private;

CommandObjectDWIMPrint::CommandObjectDWIMPrint(CommandInterpreter &interpreter)
    : CommandObjectRaw(interpreter, "dwim-print",
                       "Print a variable or expression.",
                       "dwim-print [<variable-name> | <expression>]",
                       eCommandProcessMustBePaused | eCommandTryTargetAPILock) {

  AddSimpleArgumentList(eArgTypeVarName);

  m_option_group.Append(&m_format_options,
                        OptionGroupFormat::OPTION_GROUP_FORMAT |
                            OptionGroupFormat::OPTION_GROUP_GDB_FMT,
                        LLDB_OPT_SET_1);
  StringRef exclude_expr_options[] = {"debug", "top-level"};
  m_option_group.Append(&m_expr_options, exclude_expr_options);
  m_option_group.Append(&m_varobj_options, LLDB_OPT_SET_ALL, LLDB_OPT_SET_1);
  m_option_group.Finalize();
}

Options *CommandObjectDWIMPrint::GetOptions() { return &m_option_group; }

void CommandObjectDWIMPrint::DoExecute(StringRef command,
                                       CommandReturnObject &result) {
  m_option_group.NotifyOptionParsingStarting(&m_exe_ctx);
  OptionsWithRaw args{command};
  StringRef expr = args.GetRawPart();

  if (expr.empty()) {
    result.AppendErrorWithFormatv("'{0}' takes a variable or expression",
                                  m_cmd_name);
    return;
  }

  if (args.HasArgs()) {
    if (!ParseOptionsAndNotify(args.GetArgs(), result, m_option_group,
                               m_exe_ctx))
      return;
  }

  // If the user has not specified, default to disabling persistent results.
  if (m_expr_options.suppress_persistent_result == eLazyBoolCalculate)
    m_expr_options.suppress_persistent_result = eLazyBoolYes;
  bool suppress_result = m_expr_options.ShouldSuppressResult(m_varobj_options);

  auto verbosity = GetDebugger().GetDWIMPrintVerbosity();

  Target *target_ptr = m_exe_ctx.GetTargetPtr();
  // Fallback to the dummy target, which can allow for expression evaluation.
  Target &target = target_ptr ? *target_ptr : GetDummyTarget();

  EvaluateExpressionOptions eval_options =
      m_expr_options.GetEvaluateExpressionOptions(target, m_varobj_options);
  // This command manually removes the result variable, make sure expression
  // evaluation doesn't do it first.
  eval_options.SetSuppressPersistentResult(false);

  DumpValueObjectOptions dump_options = m_varobj_options.GetAsDumpOptions(
      m_expr_options.m_verbosity, m_format_options.GetFormat());
  dump_options.SetHideRootName(suppress_result)
      .SetExpandPointerTypeFlags(lldb::eTypeIsObjC);

  bool is_po = m_varobj_options.use_objc;

  StackFrame *frame = m_exe_ctx.GetFramePtr();

  // Either the language was explicitly specified, or we check the frame.
  lldb::LanguageType language = m_expr_options.language;
  if (language == lldb::eLanguageTypeUnknown && frame)
    language = frame->GuessLanguage().AsLanguageType();

  // Add a hint if object description was requested, but no description
  // function was implemented.
  auto maybe_add_hint = [&](llvm::StringRef output) {
    static bool note_shown = false;
    if (note_shown)
      return;

    // Identify the default output of object description for Swift and
    // Objective-C
    // "<Name: 0x...>. The regex is:
    // - Start with "<".
    // - Followed by 1 or more non-whitespace characters.
    // - Followed by ": 0x".
    // - Followed by 5 or more hex digits.
    // - Followed by ">".
    // - End with zero or more whitespace characters.
    static const std::regex swift_class_regex(
        "^<\\S+: 0x[[:xdigit:]]{5,}>\\s*$");

    if (GetDebugger().GetShowDontUsePoHint() && target_ptr &&
        (language == lldb::eLanguageTypeSwift ||
         language == lldb::eLanguageTypeObjC) &&
        std::regex_match(output.data(), swift_class_regex)) {

      result.AppendNote(
          "object description requested, but type doesn't implement "
          "a custom object description. Consider using \"p\" instead of "
          "\"po\" (this note will only be shown once per debug session).\n");
      note_shown = true;
    }
  };

  // Dump `valobj` according to whether `po` was requested or not.
  auto dump_val_object = [&](ValueObject &valobj) -> Error {
    if (is_po) {
      StreamString temp_result_stream;
      if (Error err = valobj.Dump(temp_result_stream, dump_options))
        return err;
      llvm::StringRef output = temp_result_stream.GetString();
      maybe_add_hint(output);
      result.GetOutputStream() << output;
    } else {
      if (Error err = valobj.Dump(result.GetOutputStream(), dump_options))
        return err;
    }
    m_interpreter.PrintWarningsIfNecessary(result.GetOutputStream(),
                                           m_cmd_name);
    result.SetStatus(eReturnStatusSuccessFinishResult);
    return Error::success();
  };

  // First, try `expr` as a _limited_ frame variable expression path: only the
  // dot operator (`.`) is permitted for this case.
  //
  // This is limited to support only unambiguous expression paths. Of note,
  // expression paths are not attempted if the expression contain either the
  // arrow operator (`->`) or the subscript operator (`[]`). This is because
  // both operators can be overloaded in C++, and could result in ambiguity in
  // how the expression is handled. Additionally, `*` and `&` are not supported.
  const bool try_variable_path =
      expr.find_first_of("*&->[]") == StringRef::npos;
  if (frame && try_variable_path) {
    VariableSP var_sp;
    Status status;
    auto valobj_sp = frame->GetValueForVariableExpressionPath(
        expr, eval_options.GetUseDynamic(),
        StackFrame::eExpressionPathOptionsAllowDirectIVarAccess, var_sp,
        status);
    if (valobj_sp && status.Success() && valobj_sp->GetError().Success()) {
      if (!suppress_result) {
        if (auto persisted_valobj = valobj_sp->Persist())
          valobj_sp = persisted_valobj;
      }

      if (verbosity == eDWIMPrintVerbosityFull) {
        StringRef flags;
        if (args.HasArgs())
          flags = args.GetArgString();
        result.AppendNoteWithFormatv("ran `frame variable {0}{1}`", flags,
                                     expr);
      }

      Error err = dump_val_object(*valobj_sp);
      if (!err)
        return;

      // Dump failed, continue on to expression evaluation.
      LLDB_LOG_ERROR(GetLog(LLDBLog::Expressions), std::move(err),
                     "could not print frame variable '{1}': {0}", expr);
    }
  }

  // Second, try `expr` as a persistent variable.
  if (expr.starts_with("$"))
    if (auto *state = target.GetPersistentExpressionStateForLanguage(language))
      if (auto var_sp = state->GetVariable(expr))
        if (auto valobj_sp = var_sp->GetValueObject()) {
          Error err = dump_val_object(*valobj_sp);
          if (!err)
            return;

          // Dump failed, continue on to expression evaluation.
          LLDB_LOG_ERROR(GetLog(LLDBLog::Expressions), std::move(err),
                         "could not print persistent variable '{1}': {0}",
                         expr);
        }

  // Third, and lastly, try `expr` as a source expression to evaluate.
  {
    auto *exe_scope = m_exe_ctx.GetBestExecutionContextScope();
    ValueObjectSP valobj_sp;
    std::string fixed_expression;

    ExpressionResults expr_result = target.EvaluateExpression(
        expr, exe_scope, valobj_sp, eval_options, &fixed_expression);

    if (valobj_sp)
      result.GetValueObjectList().Append(valobj_sp);

    // Record the position of the expression in the command.
    std::optional<uint16_t> indent;
    if (fixed_expression.empty()) {
      size_t pos = m_original_command.rfind(expr);
      if (pos != llvm::StringRef::npos)
        indent = pos;
    }
    // Previously the indent was set up for diagnosing command line
    // parsing errors. Now point it to the expression.
    result.SetDiagnosticIndent(indent);

    // Only mention Fix-Its if the expression evaluator applied them.
    // Compiler errors refer to the final expression after applying Fix-It(s).
    if (!fixed_expression.empty() && target.GetEnableNotifyAboutFixIts()) {
      Stream &error_stream = result.GetErrorStream();
      error_stream << "  Evaluated this expression after applying Fix-It(s):\n";
      error_stream << "    " << fixed_expression << "\n";
    }

    // If the expression failed, return an error.
    if (expr_result != eExpressionCompleted) {
      if (valobj_sp)
        result.SetError(valobj_sp->GetError().Clone());
      else
        result.AppendErrorWithFormatv(
            "unknown error evaluating expression `{0}`", expr);
      return;
    }

    if (verbosity != eDWIMPrintVerbosityNone) {
      StringRef flags;
      if (args.HasArgs())
        flags = args.GetArgStringWithDelimiter();
      result.AppendNoteWithFormatv("ran `expression {0}{1}`", flags, expr);
    }

    if (valobj_sp->GetError().GetError() != UserExpression::kNoResult) {
      if (Error err = dump_val_object(*valobj_sp))
        result.SetError(std::move(err));
    } else {
      result.SetStatus(eReturnStatusSuccessFinishNoResult);
    }

    if (suppress_result)
      if (auto result_var_sp =
              target.GetPersistentVariable(valobj_sp->GetName())) {
        auto language = valobj_sp->GetPreferredDisplayLanguage();
        if (auto *persistent_state =
                target.GetPersistentExpressionStateForLanguage(language))
          persistent_state->RemovePersistentVariable(result_var_sp);
      }
  }
}
