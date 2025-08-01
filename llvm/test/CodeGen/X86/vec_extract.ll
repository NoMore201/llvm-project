; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc < %s -mtriple=i686-unknown-linux-gnu -mattr=+sse2,-sse4.1 | FileCheck %s --check-prefix=X86
; RUN: llc < %s -mtriple=x86_64-unknown-linux-gnu -mattr=+sse2,-sse4.1 | FileCheck %s --check-prefix=X64

define void @test1(ptr %F, ptr %f) nounwind {
; X86-LABEL: test1:
; X86:       # %bb.0: # %entry
; X86-NEXT:    movl {{[0-9]+}}(%esp), %eax
; X86-NEXT:    movl {{[0-9]+}}(%esp), %ecx
; X86-NEXT:    movss {{.*#+}} xmm0 = mem[0],zero,zero,zero
; X86-NEXT:    addss %xmm0, %xmm0
; X86-NEXT:    movss %xmm0, (%eax)
; X86-NEXT:    retl
;
; X64-LABEL: test1:
; X64:       # %bb.0: # %entry
; X64-NEXT:    movss {{.*#+}} xmm0 = mem[0],zero,zero,zero
; X64-NEXT:    addss %xmm0, %xmm0
; X64-NEXT:    movss %xmm0, (%rsi)
; X64-NEXT:    retq
entry:
  %tmp = load <4 x float>, ptr %F
  %tmp7 = fadd <4 x float> %tmp, %tmp
  %tmp2 = extractelement <4 x float> %tmp7, i32 0
  store float %tmp2, ptr %f
  ret void
}

define float @test2(ptr %F, ptr %f) nounwind {
; X86-LABEL: test2:
; X86:       # %bb.0: # %entry
; X86-NEXT:    pushl %eax
; X86-NEXT:    movl {{[0-9]+}}(%esp), %eax
; X86-NEXT:    movaps (%eax), %xmm0
; X86-NEXT:    addps %xmm0, %xmm0
; X86-NEXT:    movhlps {{.*#+}} xmm0 = xmm0[1,1]
; X86-NEXT:    movss %xmm0, (%esp)
; X86-NEXT:    flds (%esp)
; X86-NEXT:    popl %eax
; X86-NEXT:    retl
;
; X64-LABEL: test2:
; X64:       # %bb.0: # %entry
; X64-NEXT:    movaps (%rdi), %xmm0
; X64-NEXT:    addps %xmm0, %xmm0
; X64-NEXT:    movhlps {{.*#+}} xmm0 = xmm0[1,1]
; X64-NEXT:    retq
entry:
  %tmp = load <4 x float>, ptr %F
  %tmp7 = fadd <4 x float> %tmp, %tmp
  %tmp2 = extractelement <4 x float> %tmp7, i32 2
  ret float %tmp2
}

define void @test3(ptr %R, ptr %P1) nounwind {
; X86-LABEL: test3:
; X86:       # %bb.0: # %entry
; X86-NEXT:    movl {{[0-9]+}}(%esp), %eax
; X86-NEXT:    movl {{[0-9]+}}(%esp), %ecx
; X86-NEXT:    movaps (%ecx), %xmm0
; X86-NEXT:    shufps {{.*#+}} xmm0 = xmm0[3,3,3,3]
; X86-NEXT:    movss %xmm0, (%eax)
; X86-NEXT:    retl
;
; X64-LABEL: test3:
; X64:       # %bb.0: # %entry
; X64-NEXT:    movaps (%rsi), %xmm0
; X64-NEXT:    shufps {{.*#+}} xmm0 = xmm0[3,3,3,3]
; X64-NEXT:    movss %xmm0, (%rdi)
; X64-NEXT:    retq
entry:
  %X = load <4 x float>, ptr %P1
  %tmp = extractelement <4 x float> %X, i32 3
  store float %tmp, ptr %R
  ret void
}

define double @test4(double %A) nounwind {
; X86-LABEL: test4:
; X86:       # %bb.0: # %entry
; X86-NEXT:    subl $12, %esp
; X86-NEXT:    calll foo@PLT
; X86-NEXT:    unpckhpd {{.*#+}} xmm0 = xmm0[1,1]
; X86-NEXT:    addsd {{[0-9]+}}(%esp), %xmm0
; X86-NEXT:    movsd %xmm0, (%esp)
; X86-NEXT:    fldl (%esp)
; X86-NEXT:    addl $12, %esp
; X86-NEXT:    retl
;
; X64-LABEL: test4:
; X64:       # %bb.0: # %entry
; X64-NEXT:    pushq %rax
; X64-NEXT:    movsd %xmm0, (%rsp) # 8-byte Spill
; X64-NEXT:    callq foo@PLT
; X64-NEXT:    unpckhpd {{.*#+}} xmm0 = xmm0[1,1]
; X64-NEXT:    addsd (%rsp), %xmm0 # 8-byte Folded Reload
; X64-NEXT:    popq %rax
; X64-NEXT:    retq
entry:
  %tmp1 = call <2 x double> @foo( )
  %tmp2 = extractelement <2 x double> %tmp1, i32 1
  %tmp3 = fadd double %tmp2, %A
  ret double %tmp3
}
declare <2 x double> @foo()

define i64 @pr150117(<31 x i8> %a0) nounwind {
; X86-LABEL: pr150117:
; X86:       # %bb.0:
; X86-NEXT:    pushl %ebx
; X86-NEXT:    pushl %edi
; X86-NEXT:    pushl %esi
; X86-NEXT:    movzbl {{[0-9]+}}(%esp), %eax
; X86-NEXT:    movzbl {{[0-9]+}}(%esp), %ecx
; X86-NEXT:    movzbl {{[0-9]+}}(%esp), %esi
; X86-NEXT:    movzbl {{[0-9]+}}(%esp), %edi
; X86-NEXT:    movzbl {{[0-9]+}}(%esp), %ebx
; X86-NEXT:    movl {{[0-9]+}}(%esp), %edx
; X86-NEXT:    shll $8, %edx
; X86-NEXT:    orl %ebx, %edx
; X86-NEXT:    shll $8, %edi
; X86-NEXT:    orl %esi, %edi
; X86-NEXT:    shll $16, %ecx
; X86-NEXT:    orl %edi, %ecx
; X86-NEXT:    movl {{[0-9]+}}(%esp), %esi
; X86-NEXT:    shll $24, %esi
; X86-NEXT:    orl %ecx, %esi
; X86-NEXT:    movd %esi, %xmm0
; X86-NEXT:    pinsrw $2, %edx, %xmm0
; X86-NEXT:    movl {{[0-9]+}}(%esp), %ecx
; X86-NEXT:    shll $8, %ecx
; X86-NEXT:    orl %eax, %ecx
; X86-NEXT:    pinsrw $3, %ecx, %xmm0
; X86-NEXT:    movd %xmm0, %eax
; X86-NEXT:    pshufd {{.*#+}} xmm0 = xmm0[1,1,1,1]
; X86-NEXT:    movd %xmm0, %edx
; X86-NEXT:    popl %esi
; X86-NEXT:    popl %edi
; X86-NEXT:    popl %ebx
; X86-NEXT:    retl
;
; X64-LABEL: pr150117:
; X64:       # %bb.0:
; X64-NEXT:    movzbl {{[0-9]+}}(%rsp), %eax
; X64-NEXT:    movzbl {{[0-9]+}}(%rsp), %ecx
; X64-NEXT:    movzbl {{[0-9]+}}(%rsp), %edx
; X64-NEXT:    movzbl {{[0-9]+}}(%rsp), %esi
; X64-NEXT:    movzbl {{[0-9]+}}(%rsp), %edi
; X64-NEXT:    movl {{[0-9]+}}(%rsp), %r8d
; X64-NEXT:    shll $8, %r8d
; X64-NEXT:    orl %edi, %r8d
; X64-NEXT:    shll $8, %esi
; X64-NEXT:    orl %edx, %esi
; X64-NEXT:    shll $16, %ecx
; X64-NEXT:    orl %esi, %ecx
; X64-NEXT:    movl {{[0-9]+}}(%rsp), %edx
; X64-NEXT:    shll $24, %edx
; X64-NEXT:    orl %ecx, %edx
; X64-NEXT:    movd %edx, %xmm0
; X64-NEXT:    pinsrw $2, %r8d, %xmm0
; X64-NEXT:    movl {{[0-9]+}}(%rsp), %ecx
; X64-NEXT:    shll $8, %ecx
; X64-NEXT:    orl %eax, %ecx
; X64-NEXT:    pinsrw $3, %ecx, %xmm0
; X64-NEXT:    movq %xmm0, %rax
; X64-NEXT:    retq
  %shuffle = shufflevector <31 x i8> %a0, <31 x i8> zeroinitializer, <32 x i32> <i32 6, i32 7, i32 8, i32 9, i32 10, i32 11, i32 12, i32 13, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison>
  %bitcast = bitcast <32 x i8> %shuffle to <4 x i64>
  %elt = extractelement <4 x i64> %bitcast, i64 0
  ret i64 %elt
}

; OSS-Fuzz #15662
; https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=15662
define <4 x i32> @ossfuzz15662(ptr %in) {
; X86-LABEL: ossfuzz15662:
; X86:       # %bb.0:
; X86-NEXT:    xorps %xmm0, %xmm0
; X86-NEXT:    movaps %xmm0, (%eax)
; X86-NEXT:    retl
;
; X64-LABEL: ossfuzz15662:
; X64:       # %bb.0:
; X64-NEXT:    xorps %xmm0, %xmm0
; X64-NEXT:    movaps %xmm0, (%rax)
; X64-NEXT:    retq
   %C10 = icmp ule i1 false, false
   %C3 = icmp ule i1 true, undef
   %B = sdiv i1 %C10, %C3
   %I = insertelement <4 x i32> zeroinitializer, i32 0, i1 %B
   store <4 x i32> %I, ptr undef
   ret <4 x i32> zeroinitializer
}
