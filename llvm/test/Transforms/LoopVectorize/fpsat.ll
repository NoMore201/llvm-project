; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: opt %s -passes=loop-vectorize -force-vector-interleave=1 -force-vector-width=4 -S | FileCheck %s

define void @signed(ptr %x, ptr %y, i32 %n) {
; CHECK-LABEL: @signed(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[X2:%.*]] = ptrtoint ptr [[X:%.*]] to i64
; CHECK-NEXT:    [[Y1:%.*]] = ptrtoint ptr [[Y:%.*]] to i64
; CHECK-NEXT:    [[CMP6:%.*]] = icmp sgt i32 [[N:%.*]], 0
; CHECK-NEXT:    br i1 [[CMP6]], label [[FOR_BODY_PREHEADER:%.*]], label [[FOR_COND_CLEANUP:%.*]]
; CHECK:       for.body.preheader:
; CHECK-NEXT:    [[WIDE_TRIP_COUNT:%.*]] = zext i32 [[N]] to i64
; CHECK-NEXT:    [[MIN_ITERS_CHECK:%.*]] = icmp ult i64 [[WIDE_TRIP_COUNT]], 4
; CHECK-NEXT:    br i1 [[MIN_ITERS_CHECK]], label [[SCALAR_PH:%.*]], label [[VECTOR_MEMCHECK:%.*]]
; CHECK:       vector.memcheck:
; CHECK-NEXT:    [[TMP0:%.*]] = sub i64 [[Y1]], [[X2]]
; CHECK-NEXT:    [[DIFF_CHECK:%.*]] = icmp ult i64 [[TMP0]], 16
; CHECK-NEXT:    br i1 [[DIFF_CHECK]], label [[SCALAR_PH]], label [[VECTOR_PH:%.*]]
; CHECK:       vector.ph:
; CHECK-NEXT:    [[N_MOD_VF:%.*]] = urem i64 [[WIDE_TRIP_COUNT]], 4
; CHECK-NEXT:    [[N_VEC:%.*]] = sub i64 [[WIDE_TRIP_COUNT]], [[N_MOD_VF]]
; CHECK-NEXT:    br label [[VECTOR_BODY:%.*]]
; CHECK:       vector.body:
; CHECK-NEXT:    [[INDEX:%.*]] = phi i64 [ 0, [[VECTOR_PH]] ], [ [[INDEX_NEXT:%.*]], [[VECTOR_BODY]] ]
; CHECK-NEXT:    [[TMP2:%.*]] = getelementptr inbounds float, ptr [[X]], i64 [[INDEX]]
; CHECK-NEXT:    [[WIDE_LOAD:%.*]] = load <4 x float>, ptr [[TMP2]], align 4
; CHECK-NEXT:    [[TMP4:%.*]] = call <4 x i32> @llvm.fptosi.sat.v4i32.v4f32(<4 x float> [[WIDE_LOAD]])
; CHECK-NEXT:    [[TMP5:%.*]] = getelementptr inbounds i32, ptr [[Y]], i64 [[INDEX]]
; CHECK-NEXT:    store <4 x i32> [[TMP4]], ptr [[TMP5]], align 4
; CHECK-NEXT:    [[INDEX_NEXT]] = add nuw i64 [[INDEX]], 4
; CHECK-NEXT:    [[TMP7:%.*]] = icmp eq i64 [[INDEX_NEXT]], [[N_VEC]]
; CHECK-NEXT:    br i1 [[TMP7]], label [[MIDDLE_BLOCK:%.*]], label [[VECTOR_BODY]], !llvm.loop [[LOOP0:![0-9]+]]
; CHECK:       middle.block:
; CHECK-NEXT:    [[CMP_N:%.*]] = icmp eq i64 [[WIDE_TRIP_COUNT]], [[N_VEC]]
; CHECK-NEXT:    br i1 [[CMP_N]], label [[FOR_COND_CLEANUP_LOOPEXIT:%.*]], label [[SCALAR_PH]]
; CHECK:       scalar.ph:
; CHECK-NEXT:    [[BC_RESUME_VAL:%.*]] = phi i64 [ [[N_VEC]], [[MIDDLE_BLOCK]] ], [ 0, [[FOR_BODY_PREHEADER]] ], [ 0, [[VECTOR_MEMCHECK]] ]
; CHECK-NEXT:    br label [[FOR_BODY:%.*]]
; CHECK:       for.cond.cleanup.loopexit:
; CHECK-NEXT:    br label [[FOR_COND_CLEANUP]]
; CHECK:       for.cond.cleanup:
; CHECK-NEXT:    ret void
; CHECK:       for.body:
; CHECK-NEXT:    [[INDVARS_IV:%.*]] = phi i64 [ [[BC_RESUME_VAL]], [[SCALAR_PH]] ], [ [[INDVARS_IV_NEXT:%.*]], [[FOR_BODY]] ]
; CHECK-NEXT:    [[ARRAYIDX:%.*]] = getelementptr inbounds float, ptr [[X]], i64 [[INDVARS_IV]]
; CHECK-NEXT:    [[TMP8:%.*]] = load float, ptr [[ARRAYIDX]], align 4
; CHECK-NEXT:    [[TMP9:%.*]] = tail call i32 @llvm.fptosi.sat.i32.f32(float [[TMP8]])
; CHECK-NEXT:    [[ARRAYIDX2:%.*]] = getelementptr inbounds i32, ptr [[Y]], i64 [[INDVARS_IV]]
; CHECK-NEXT:    store i32 [[TMP9]], ptr [[ARRAYIDX2]], align 4
; CHECK-NEXT:    [[INDVARS_IV_NEXT]] = add nuw nsw i64 [[INDVARS_IV]], 1
; CHECK-NEXT:    [[EXITCOND_NOT:%.*]] = icmp eq i64 [[INDVARS_IV_NEXT]], [[WIDE_TRIP_COUNT]]
; CHECK-NEXT:    br i1 [[EXITCOND_NOT]], label [[FOR_COND_CLEANUP_LOOPEXIT]], label [[FOR_BODY]], !llvm.loop [[LOOP3:![0-9]+]]
;
entry:
  %cmp6 = icmp sgt i32 %n, 0
  br i1 %cmp6, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds float, ptr %x, i64 %indvars.iv
  %0 = load float, ptr %arrayidx, align 4
  %1 = tail call i32 @llvm.fptosi.sat.i32.f32(float %0)
  %arrayidx2 = getelementptr inbounds i32, ptr %y, i64 %indvars.iv
  store i32 %1, ptr %arrayidx2, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

define void @unsigned(ptr %x, ptr %y, i32 %n) {
; CHECK-LABEL: @unsigned(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[X2:%.*]] = ptrtoint ptr [[X:%.*]] to i64
; CHECK-NEXT:    [[Y1:%.*]] = ptrtoint ptr [[Y:%.*]] to i64
; CHECK-NEXT:    [[CMP6:%.*]] = icmp sgt i32 [[N:%.*]], 0
; CHECK-NEXT:    br i1 [[CMP6]], label [[FOR_BODY_PREHEADER:%.*]], label [[FOR_COND_CLEANUP:%.*]]
; CHECK:       for.body.preheader:
; CHECK-NEXT:    [[WIDE_TRIP_COUNT:%.*]] = zext i32 [[N]] to i64
; CHECK-NEXT:    [[MIN_ITERS_CHECK:%.*]] = icmp ult i64 [[WIDE_TRIP_COUNT]], 4
; CHECK-NEXT:    br i1 [[MIN_ITERS_CHECK]], label [[SCALAR_PH:%.*]], label [[VECTOR_MEMCHECK:%.*]]
; CHECK:       vector.memcheck:
; CHECK-NEXT:    [[TMP0:%.*]] = sub i64 [[Y1]], [[X2]]
; CHECK-NEXT:    [[DIFF_CHECK:%.*]] = icmp ult i64 [[TMP0]], 16
; CHECK-NEXT:    br i1 [[DIFF_CHECK]], label [[SCALAR_PH]], label [[VECTOR_PH:%.*]]
; CHECK:       vector.ph:
; CHECK-NEXT:    [[N_MOD_VF:%.*]] = urem i64 [[WIDE_TRIP_COUNT]], 4
; CHECK-NEXT:    [[N_VEC:%.*]] = sub i64 [[WIDE_TRIP_COUNT]], [[N_MOD_VF]]
; CHECK-NEXT:    br label [[VECTOR_BODY:%.*]]
; CHECK:       vector.body:
; CHECK-NEXT:    [[INDEX:%.*]] = phi i64 [ 0, [[VECTOR_PH]] ], [ [[INDEX_NEXT:%.*]], [[VECTOR_BODY]] ]
; CHECK-NEXT:    [[TMP2:%.*]] = getelementptr inbounds float, ptr [[X]], i64 [[INDEX]]
; CHECK-NEXT:    [[WIDE_LOAD:%.*]] = load <4 x float>, ptr [[TMP2]], align 4
; CHECK-NEXT:    [[TMP4:%.*]] = call <4 x i32> @llvm.fptoui.sat.v4i32.v4f32(<4 x float> [[WIDE_LOAD]])
; CHECK-NEXT:    [[TMP5:%.*]] = getelementptr inbounds i32, ptr [[Y]], i64 [[INDEX]]
; CHECK-NEXT:    store <4 x i32> [[TMP4]], ptr [[TMP5]], align 4
; CHECK-NEXT:    [[INDEX_NEXT]] = add nuw i64 [[INDEX]], 4
; CHECK-NEXT:    [[TMP7:%.*]] = icmp eq i64 [[INDEX_NEXT]], [[N_VEC]]
; CHECK-NEXT:    br i1 [[TMP7]], label [[MIDDLE_BLOCK:%.*]], label [[VECTOR_BODY]], !llvm.loop [[LOOP4:![0-9]+]]
; CHECK:       middle.block:
; CHECK-NEXT:    [[CMP_N:%.*]] = icmp eq i64 [[WIDE_TRIP_COUNT]], [[N_VEC]]
; CHECK-NEXT:    br i1 [[CMP_N]], label [[FOR_COND_CLEANUP_LOOPEXIT:%.*]], label [[SCALAR_PH]]
; CHECK:       scalar.ph:
; CHECK-NEXT:    [[BC_RESUME_VAL:%.*]] = phi i64 [ [[N_VEC]], [[MIDDLE_BLOCK]] ], [ 0, [[FOR_BODY_PREHEADER]] ], [ 0, [[VECTOR_MEMCHECK]] ]
; CHECK-NEXT:    br label [[FOR_BODY:%.*]]
; CHECK:       for.cond.cleanup.loopexit:
; CHECK-NEXT:    br label [[FOR_COND_CLEANUP]]
; CHECK:       for.cond.cleanup:
; CHECK-NEXT:    ret void
; CHECK:       for.body:
; CHECK-NEXT:    [[INDVARS_IV:%.*]] = phi i64 [ [[BC_RESUME_VAL]], [[SCALAR_PH]] ], [ [[INDVARS_IV_NEXT:%.*]], [[FOR_BODY]] ]
; CHECK-NEXT:    [[ARRAYIDX:%.*]] = getelementptr inbounds float, ptr [[X]], i64 [[INDVARS_IV]]
; CHECK-NEXT:    [[TMP8:%.*]] = load float, ptr [[ARRAYIDX]], align 4
; CHECK-NEXT:    [[TMP9:%.*]] = tail call i32 @llvm.fptoui.sat.i32.f32(float [[TMP8]])
; CHECK-NEXT:    [[ARRAYIDX2:%.*]] = getelementptr inbounds i32, ptr [[Y]], i64 [[INDVARS_IV]]
; CHECK-NEXT:    store i32 [[TMP9]], ptr [[ARRAYIDX2]], align 4
; CHECK-NEXT:    [[INDVARS_IV_NEXT]] = add nuw nsw i64 [[INDVARS_IV]], 1
; CHECK-NEXT:    [[EXITCOND_NOT:%.*]] = icmp eq i64 [[INDVARS_IV_NEXT]], [[WIDE_TRIP_COUNT]]
; CHECK-NEXT:    br i1 [[EXITCOND_NOT]], label [[FOR_COND_CLEANUP_LOOPEXIT]], label [[FOR_BODY]], !llvm.loop [[LOOP5:![0-9]+]]
;
entry:
  %cmp6 = icmp sgt i32 %n, 0
  br i1 %cmp6, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds float, ptr %x, i64 %indvars.iv
  %0 = load float, ptr %arrayidx, align 4
  %1 = tail call i32 @llvm.fptoui.sat.i32.f32(float %0)
  %arrayidx2 = getelementptr inbounds i32, ptr %y, i64 %indvars.iv
  store i32 %1, ptr %arrayidx2, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

declare i32 @llvm.fptosi.sat.i32.f32(float)
declare i32 @llvm.fptoui.sat.i32.f32(float)
