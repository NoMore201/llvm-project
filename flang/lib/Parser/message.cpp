//===-- lib/Parser/message.cpp --------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "flang/Parser/message.h"
#include "flang/Common/idioms.h"
#include "flang/Parser/char-set.h"
#include "llvm/Support/raw_ostream.h"
#include <algorithm>
#include <cstdarg>
#include <cstddef>
#include <cstdio>
#include <cstring>
#include <string>
#include <tuple>
#include <vector>

namespace Fortran::parser {

llvm::raw_ostream &operator<<(llvm::raw_ostream &o, const MessageFixedText &t) {
  std::size_t n{t.text().size()};
  for (std::size_t j{0}; j < n; ++j) {
    o << t.text()[j];
  }
  return o;
}

void MessageFormattedText::Format(const MessageFixedText *text, ...) {
  const char *p{text->text().begin()};
  std::string asString;
  if (*text->text().end() != '\0') {
    // not NUL-terminated
    asString = text->text().NULTerminatedToString();
    p = asString.c_str();
  }
  va_list ap;
  va_start(ap, text);
#ifdef _MSC_VER
  // Microsoft has a separate function for "positional arguments", which is
  // used in some messages.
  int need{_vsprintf_p(nullptr, 0, p, ap)};
#else
  int need{vsnprintf(nullptr, 0, p, ap)};
#endif

  CHECK(need >= 0);
  char *buffer{
      static_cast<char *>(std::malloc(static_cast<std::size_t>(need) + 1))};
  CHECK(buffer);
  va_end(ap);
  va_start(ap, text);
#ifdef _MSC_VER
  // Use positional argument variant of printf.
  int need2{_vsprintf_p(buffer, need + 1, p, ap)};
#else
  int need2{vsnprintf(buffer, need + 1, p, ap)};
#endif
  CHECK(need2 == need);
  va_end(ap);
  string_ = buffer;
  std::free(buffer);
  conversions_.clear();
}

const char *MessageFormattedText::Convert(const std::string &s) {
  conversions_.emplace_front(s);
  return conversions_.front().c_str();
}

const char *MessageFormattedText::Convert(std::string &&s) {
  conversions_.emplace_front(std::move(s));
  return conversions_.front().c_str();
}

const char *MessageFormattedText::Convert(const std::string_view &s) {
  conversions_.emplace_front(s);
  return conversions_.front().c_str();
}

const char *MessageFormattedText::Convert(std::string_view &&s) {
  conversions_.emplace_front(s);
  return conversions_.front().c_str();
}

const char *MessageFormattedText::Convert(CharBlock x) {
  return Convert(x.ToString());
}

std::string MessageExpectedText::ToString() const {
  return common::visit(
      common::visitors{
          [](CharBlock cb) {
            return MessageFormattedText("expected '%s'"_err_en_US, cb)
                .MoveString();
          },
          [](const SetOfChars &set) {
            SetOfChars expect{set};
            if (expect.Has('\n')) {
              expect = expect.Difference('\n');
              if (expect.empty()) {
                return "expected end of line"_err_en_US.text().ToString();
              } else {
                std::string s{expect.ToString()};
                if (s.size() == 1) {
                  return MessageFormattedText(
                      "expected end of line or '%s'"_err_en_US, s)
                      .MoveString();
                } else {
                  return MessageFormattedText(
                      "expected end of line or one of '%s'"_err_en_US, s)
                      .MoveString();
                }
              }
            }
            std::string s{expect.ToString()};
            if (s.size() != 1) {
              return MessageFormattedText("expected one of '%s'"_err_en_US, s)
                  .MoveString();
            } else {
              return MessageFormattedText("expected '%s'"_err_en_US, s)
                  .MoveString();
            }
          },
      },
      u_);
}

bool MessageExpectedText::Merge(const MessageExpectedText &that) {
  return common::visit(common::visitors{
                           [](SetOfChars &s1, const SetOfChars &s2) {
                             s1 = s1.Union(s2);
                             return true;
                           },
                           [](const auto &, const auto &) { return false; },
                       },
      u_, that.u_);
}

bool Message::SortBefore(const Message &that) const {
  // Messages from prescanning have ProvenanceRange values for their locations,
  // while messages from later phases have CharBlock values, since the
  // conversion of cooked source stream locations to provenances is not
  // free and needs to be deferred, and many messages created during parsing
  // are speculative.  Messages with ProvenanceRange locations are ordered
  // before others for sorting.
  return common::visit(
      common::visitors{
          [](CharBlock cb1, CharBlock cb2) {
            return cb1.begin() < cb2.begin();
          },
          [](CharBlock, const ProvenanceRange &) { return false; },
          [](const ProvenanceRange &pr1, const ProvenanceRange &pr2) {
            return pr1.start() < pr2.start();
          },
          [](const ProvenanceRange &, CharBlock) { return true; },
      },
      location_, that.location_);
}

bool Message::IsFatal() const {
  return severity() == Severity::Error || severity() == Severity::Todo;
}

Severity Message::severity() const {
  return common::visit(
      common::visitors{
          [](const MessageExpectedText &) { return Severity::Error; },
          [](const MessageFixedText &x) { return x.severity(); },
          [](const MessageFormattedText &x) { return x.severity(); },
      },
      text_);
}

Message &Message::set_severity(Severity severity) {
  common::visit(
      common::visitors{
          [](const MessageExpectedText &) {},
          [severity](MessageFixedText &x) { x.set_severity(severity); },
          [severity](MessageFormattedText &x) { x.set_severity(severity); },
      },
      text_);
  return *this;
}

std::optional<common::LanguageFeature> Message::languageFeature() const {
  return languageFeature_;
}

Message &Message::set_languageFeature(common::LanguageFeature feature) {
  languageFeature_ = feature;
  return *this;
}

std::optional<common::UsageWarning> Message::usageWarning() const {
  return usageWarning_;
}

Message &Message::set_usageWarning(common::UsageWarning warning) {
  usageWarning_ = warning;
  return *this;
}

std::string Message::ToString() const {
  return common::visit(
      common::visitors{
          [](const MessageFixedText &t) {
            return t.text().NULTerminatedToString();
          },
          [](const MessageFormattedText &t) { return t.string(); },
          [](const MessageExpectedText &e) { return e.ToString(); },
      },
      text_);
}

void Message::ResolveProvenances(const AllCookedSources &allCooked) {
  if (CharBlock * cb{std::get_if<CharBlock>(&location_)}) {
    if (std::optional<ProvenanceRange> resolved{
            allCooked.GetProvenanceRange(*cb)}) {
      location_ = *resolved;
    }
  }
  if (Message * attachment{attachment_.get()}) {
    attachment->ResolveProvenances(allCooked);
  }
}

std::optional<ProvenanceRange> Message::GetProvenanceRange(
    const AllCookedSources &allCooked) const {
  return common::visit(
      common::visitors{
          [&](CharBlock cb) { return allCooked.GetProvenanceRange(cb); },
          [](const ProvenanceRange &pr) { return std::make_optional(pr); },
      },
      location_);
}

static std::string Prefix(Severity severity) {
  switch (severity) {
  case Severity::Error:
    return "error: ";
  case Severity::Warning:
    return "warning: ";
  case Severity::Portability:
    return "portability: ";
  case Severity::Because:
    return "because: ";
  case Severity::Context:
    return "in the context: ";
  case Severity::Todo:
    return "error: not yet implemented: ";
  case Severity::None:
    break;
  }
  return "";
}

static llvm::raw_ostream::Colors PrefixColor(Severity severity) {
  switch (severity) {
  case Severity::Error:
  case Severity::Todo:
    return llvm::raw_ostream::RED;
  case Severity::Warning:
  case Severity::Portability:
    return llvm::raw_ostream::MAGENTA;
  default:
    // TODO: Set the color.
    break;
  }
  return llvm::raw_ostream::SAVEDCOLOR;
}

static std::string HintLanguageControlFlag(
    const common::LanguageFeatureControl *hintFlagPtr,
    std::optional<common::LanguageFeature> feature,
    std::optional<common::UsageWarning> warning) {
  if (hintFlagPtr) {
    std::string flag;
    if (warning) {
      flag = hintFlagPtr->getDefaultCliSpelling(*warning);
    } else if (feature) {
      flag = hintFlagPtr->getDefaultCliSpelling(*feature);
    }
    if (!flag.empty()) {
      return " [-W" + flag + "]";
    }
  }
  return "";
}

static constexpr int MAX_CONTEXTS_EMITTED{2};
static constexpr bool OMIT_SHARED_CONTEXTS{true};

void Message::Emit(llvm::raw_ostream &o, const AllCookedSources &allCooked,
    bool echoSourceLine,
    const common::LanguageFeatureControl *hintFlagPtr) const {
  std::optional<ProvenanceRange> provenanceRange{GetProvenanceRange(allCooked)};
  const AllSources &sources{allCooked.allSources()};
  const std::string text{ToString()};
  const std::string hint{
      HintLanguageControlFlag(hintFlagPtr, languageFeature_, usageWarning_)};
  sources.EmitMessage(o, provenanceRange, text + hint, Prefix(severity()),
      PrefixColor(severity()), echoSourceLine);
  // Refers to whether the attachment in the loop below is a context, but can't
  // be declared inside the loop because the previous iteration's
  // attachment->attachmentIsContext_ indicates this.
  bool isContext{attachmentIsContext_};
  int contextsEmitted{0};
  // Emit attachments.
  for (const Message *attachment{attachment_.get()}; attachment;
      isContext = attachment->attachmentIsContext_,
      attachment = attachment->attachment_.get()) {
    Severity severity = isContext ? Severity::Context : attachment->severity();
    auto emitAttachment = [&]() {
      sources.EmitMessage(o, attachment->GetProvenanceRange(allCooked),
          attachment->ToString(), Prefix(severity), PrefixColor(severity),
          echoSourceLine);
    };

    if (isContext) {
      // Truncate the number of contexts emitted.
      if (contextsEmitted < MAX_CONTEXTS_EMITTED) {
        emitAttachment();
        ++contextsEmitted;
      }
      if constexpr (OMIT_SHARED_CONTEXTS) {
        // Skip less specific contexts at the same location.
        for (const Message *next_attachment{attachment->attachment_.get()};
            next_attachment && next_attachment->attachmentIsContext_ &&
            next_attachment->AtSameLocation(*attachment);
            next_attachment = next_attachment->attachment_.get()) {
          attachment = next_attachment;
        }
        // NB, this loop increments `attachment` one more time after the
        // previous loop is done advancing it to the last context at the same
        // location.
      }
    } else {
      emitAttachment();
    }
  }
}

// Messages are equal if they're for the same location and text, and the user
// visible aspects of their attachments are the same
bool Message::operator==(const Message &that) const {
  if (!AtSameLocation(that) || ToString() != that.ToString() ||
      severity() != that.severity() ||
      attachmentIsContext_ != that.attachmentIsContext_) {
    return false;
  }
  const Message *thatAttachment{that.attachment_.get()};
  for (const Message *attachment{attachment_.get()}; attachment;
      attachment = attachment->attachment_.get()) {
    if (!thatAttachment || !attachment->AtSameLocation(*thatAttachment) ||
        attachment->ToString() != thatAttachment->ToString() ||
        attachment->severity() != thatAttachment->severity()) {
      return false;
    }
    thatAttachment = thatAttachment->attachment_.get();
  }
  return !thatAttachment;
}

bool Message::Merge(const Message &that) {
  return AtSameLocation(that) &&
      (!that.attachment_.get() ||
          attachment_.get() == that.attachment_.get()) &&
      common::visit(
          common::visitors{
              [](MessageExpectedText &e1, const MessageExpectedText &e2) {
                return e1.Merge(e2);
              },
              [](const auto &, const auto &) { return false; },
          },
          text_, that.text_);
}

Message &Message::Attach(Message *m) {
  if (!attachment_) {
    attachment_ = m;
  } else {
    if (attachment_->references() > 1) {
      // Don't attach to a shared context attachment; copy it first.
      attachment_ = new Message{*attachment_};
    }
    attachment_->Attach(m);
  }
  return *this;
}

Message &Message::Attach(std::unique_ptr<Message> &&m) {
  return Attach(m.release());
}

bool Message::AtSameLocation(const Message &that) const {
  return common::visit(
      common::visitors{
          [](CharBlock cb1, CharBlock cb2) {
            return cb1.begin() == cb2.begin();
          },
          [](const ProvenanceRange &pr1, const ProvenanceRange &pr2) {
            return pr1.start() == pr2.start();
          },
          [](const auto &, const auto &) { return false; },
      },
      location_, that.location_);
}

bool Messages::Merge(const Message &msg) {
  if (msg.IsMergeable()) {
    for (auto &m : messages_) {
      if (m.Merge(msg)) {
        return true;
      }
    }
  }
  return false;
}

void Messages::Merge(Messages &&that) {
  if (messages_.empty()) {
    *this = std::move(that);
  } else {
    while (!that.messages_.empty()) {
      if (Merge(that.messages_.front())) {
        that.messages_.pop_front();
      } else {
        auto next{that.messages_.begin()};
        ++next;
        messages_.splice(
            messages_.end(), that.messages_, that.messages_.begin(), next);
      }
    }
  }
}

void Messages::Copy(const Messages &that) {
  for (const Message &m : that.messages_) {
    Message copy{m};
    Say(std::move(copy));
  }
}

void Messages::ResolveProvenances(const AllCookedSources &allCooked) {
  for (Message &m : messages_) {
    m.ResolveProvenances(allCooked);
  }
}

void Messages::Emit(llvm::raw_ostream &o, const AllCookedSources &allCooked,
    bool echoSourceLines, const common::LanguageFeatureControl *hintFlagPtr,
    std::size_t maxErrorsToEmit, bool warningsAreErrors) const {
  std::vector<const Message *> sorted;
  for (const auto &msg : messages_) {
    sorted.push_back(&msg);
  }
  std::stable_sort(sorted.begin(), sorted.end(),
      [](const Message *x, const Message *y) { return x->SortBefore(*y); });
  const Message *lastMsg{nullptr};
  std::size_t errorsEmitted{0};
  for (const Message *msg : sorted) {
    if (lastMsg && *msg == *lastMsg) {
      // Don't emit two identical messages for the same location
      continue;
    }
    msg->Emit(o, allCooked, echoSourceLines, hintFlagPtr);
    lastMsg = msg;
    if (warningsAreErrors || msg->IsFatal()) {
      ++errorsEmitted;
    }
    // If maxErrorsToEmit is 0, emit all errors, otherwise break after
    // maxErrorsToEmit.
    if (maxErrorsToEmit > 0 && errorsEmitted >= maxErrorsToEmit) {
      break;
    }
  }
}

void Messages::AttachTo(Message &msg, std::optional<Severity> severity) {
  for (Message &m : messages_) {
    Message m2{std::move(m)};
    if (severity) {
      m2.set_severity(*severity);
    }
    msg.Attach(std::move(m2));
  }
  messages_.clear();
}

bool Messages::AnyFatalError(bool warningsAreErrors) const {
  // Short-circuit in the most common case.
  if (messages_.empty()) {
    return false;
  }
  // If warnings are errors and there are warnings or errors, this is fatal.
  // This preserves the compiler's current behavior of treating any non-fatal
  // message as a warning. We may want to refine this in the future.
  if (warningsAreErrors) {
    return true;
  }
  // Otherwise, check the message buffer for fatal errors.
  for (const auto &msg : messages_) {
    if (msg.IsFatal()) {
      return true;
    }
  }
  return false;
}
} // namespace Fortran::parser
