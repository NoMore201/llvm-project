; NOTE: Assertions have been autogenerated by utils/update_test_checks.py UTC_ARGS: --check-globals none --version 5
; RUN: opt -p loop-vectorize -S %s | FileCheck %s

target triple = "aarch64-unknown-linux-gnu"

define void @licm_replicate_call(double %x, ptr %dst) {
; CHECK-LABEL: define void @licm_replicate_call(
; CHECK-SAME: double [[X:%.*]], ptr [[DST:%.*]]) {
; CHECK-NEXT:  [[ENTRY:.*]]:
; CHECK-NEXT:    br i1 false, label %[[SCALAR_PH:.*]], label %[[VECTOR_PH:.*]]
; CHECK:       [[VECTOR_PH]]:
; CHECK-NEXT:    [[TMP0:%.*]] = tail call double @llvm.pow.f64(double [[X]], double 3.000000e+00)
; CHECK-NEXT:    [[TMP1:%.*]] = tail call double @llvm.pow.f64(double [[X]], double 3.000000e+00)
; CHECK-NEXT:    [[TMP2:%.*]] = insertelement <2 x double> poison, double [[TMP0]], i32 0
; CHECK-NEXT:    [[TMP3:%.*]] = insertelement <2 x double> [[TMP2]], double [[TMP1]], i32 1
; CHECK-NEXT:    br label %[[VECTOR_BODY:.*]]
; CHECK:       [[VECTOR_BODY]]:
; CHECK-NEXT:    [[INDEX:%.*]] = phi i64 [ 0, %[[VECTOR_PH]] ], [ [[INDEX_NEXT:%.*]], %[[VECTOR_BODY]] ]
; CHECK-NEXT:    [[VEC_IND:%.*]] = phi <2 x i32> [ <i32 0, i32 1>, %[[VECTOR_PH]] ], [ [[VEC_IND_NEXT:%.*]], %[[VECTOR_BODY]] ]
; CHECK-NEXT:    [[STEP_ADD:%.*]] = add <2 x i32> [[VEC_IND]], splat (i32 2)
; CHECK-NEXT:    [[TMP4:%.*]] = uitofp <2 x i32> [[VEC_IND]] to <2 x double>
; CHECK-NEXT:    [[TMP5:%.*]] = uitofp <2 x i32> [[STEP_ADD]] to <2 x double>
; CHECK-NEXT:    [[TMP6:%.*]] = fmul <2 x double> [[TMP3]], [[TMP4]]
; CHECK-NEXT:    [[TMP7:%.*]] = fmul <2 x double> [[TMP3]], [[TMP5]]
; CHECK-NEXT:    [[TMP8:%.*]] = getelementptr inbounds double, ptr [[DST]], i64 [[INDEX]]
; CHECK-NEXT:    [[TMP10:%.*]] = getelementptr inbounds double, ptr [[TMP8]], i32 2
; CHECK-NEXT:    store <2 x double> [[TMP6]], ptr [[TMP8]], align 8
; CHECK-NEXT:    store <2 x double> [[TMP7]], ptr [[TMP10]], align 8
; CHECK-NEXT:    [[INDEX_NEXT]] = add nuw i64 [[INDEX]], 4
; CHECK-NEXT:    [[VEC_IND_NEXT]] = add <2 x i32> [[STEP_ADD]], splat (i32 2)
; CHECK-NEXT:    [[TMP11:%.*]] = icmp eq i64 [[INDEX_NEXT]], 128
; CHECK-NEXT:    br i1 [[TMP11]], label %[[MIDDLE_BLOCK:.*]], label %[[VECTOR_BODY]], !llvm.loop [[LOOP0:![0-9]+]]
; CHECK:       [[MIDDLE_BLOCK]]:
; CHECK-NEXT:    br label %[[SCALAR_PH]]
; CHECK:       [[SCALAR_PH]]:
; CHECK-NEXT:    [[BC_RESUME_VAL:%.*]] = phi i64 [ 128, %[[MIDDLE_BLOCK]] ], [ 0, %[[ENTRY]] ]
; CHECK-NEXT:    br label %[[LOOP:.*]]
; CHECK:       [[LOOP]]:
; CHECK-NEXT:    [[IV:%.*]] = phi i64 [ [[BC_RESUME_VAL]], %[[SCALAR_PH]] ], [ [[IV_NEXT:%.*]], %[[LOOP]] ]
; CHECK-NEXT:    [[IV_TRUNC:%.*]] = trunc i64 [[IV]] to i32
; CHECK-NEXT:    [[IV_AS_FP:%.*]] = uitofp i32 [[IV_TRUNC]] to double
; CHECK-NEXT:    [[P:%.*]] = tail call double @llvm.pow.f64(double [[X]], double 3.000000e+00)
; CHECK-NEXT:    [[MUL:%.*]] = fmul double [[P]], [[IV_AS_FP]]
; CHECK-NEXT:    [[GEP_DST:%.*]] = getelementptr inbounds double, ptr [[DST]], i64 [[IV]]
; CHECK-NEXT:    store double [[MUL]], ptr [[GEP_DST]], align 8
; CHECK-NEXT:    [[IV_NEXT]] = add i64 [[IV]], 1
; CHECK-NEXT:    [[EC:%.*]] = icmp eq i64 [[IV]], 128
; CHECK-NEXT:    br i1 [[EC]], label %[[EXIT:.*]], label %[[LOOP]], !llvm.loop [[LOOP3:![0-9]+]]
; CHECK:       [[EXIT]]:
; CHECK-NEXT:    ret void
;
entry:
  br label %loop

loop:
  %iv = phi i64 [ 0, %entry ], [ %iv.next, %loop ]
  %iv.trunc = trunc i64 %iv to i32
  %iv.as.fp = uitofp i32 %iv.trunc to double
  %p = tail call double @llvm.pow.f64(double %x, double 3.000000e+00)
  %mul = fmul double %p, %iv.as.fp
  %gep.dst = getelementptr inbounds double, ptr %dst, i64 %iv
  store double %mul, ptr %gep.dst, align 8
  %iv.next = add i64 %iv, 1
  %ec = icmp eq i64 %iv, 128
  br i1 %ec, label %exit, label %loop

exit:
  ret void
}

declare double @llvm.pow.f64(double, double)
