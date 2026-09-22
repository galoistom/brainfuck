; ModuleID = 'test.c'
source_filename = "test.c"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

%struct.array = type { ptr, i64, i64 }

@.str = private unnamed_addr constant [4 x i8] c"%zu\00", align 1

; Function Attrs: noinline nounwind optnone sspstrong uwtable
define dso_local void @moveTo(ptr noundef %0, i64 noundef %1) #0 {
  %3 = alloca ptr, align 8
  %4 = alloca i64, align 8
  store ptr %0, ptr %3, align 8
  store i64 %1, ptr %4, align 8
  br label %5

5:                                                ; preds = %11, %2
  %6 = load ptr, ptr %3, align 8
  %7 = getelementptr inbounds nuw %struct.array, ptr %6, i32 0, i32 1
  %8 = load i64, ptr %7, align 8
  %9 = load i64, ptr %4, align 8
  %10 = icmp ule i64 %8, %9
  br i1 %10, label %11, label %26

11:                                               ; preds = %5
  %12 = load ptr, ptr %3, align 8
  %13 = getelementptr inbounds nuw %struct.array, ptr %12, i32 0, i32 1
  %14 = load i64, ptr %13, align 8
  %15 = mul i64 %14, 2
  store i64 %15, ptr %13, align 8
  %16 = load ptr, ptr %3, align 8
  %17 = getelementptr inbounds nuw %struct.array, ptr %16, i32 0, i32 0
  %18 = load ptr, ptr %17, align 8
  %19 = load ptr, ptr %3, align 8
  %20 = getelementptr inbounds nuw %struct.array, ptr %19, i32 0, i32 1
  %21 = load i64, ptr %20, align 8
  %22 = mul i64 %21, 1
  %23 = call ptr @realloc(ptr noundef %18, i64 noundef %22) #4
  %24 = load ptr, ptr %3, align 8
  %25 = getelementptr inbounds nuw %struct.array, ptr %24, i32 0, i32 0
  store ptr %23, ptr %25, align 8
  br label %5, !llvm.loop !6

26:                                               ; preds = %5
  %27 = load i64, ptr %4, align 8
  %28 = load ptr, ptr %3, align 8
  %29 = getelementptr inbounds nuw %struct.array, ptr %28, i32 0, i32 2
  store i64 %27, ptr %29, align 8
  ret void
}

; Function Attrs: nounwind allocsize(1)
declare ptr @realloc(ptr noundef, i64 noundef) #1

; Function Attrs: noinline nounwind optnone sspstrong uwtable
define dso_local i32 @main() #0 {
  %1 = alloca i32, align 4
  %2 = alloca %struct.array, align 8
  store i32 0, ptr %1, align 4
  %3 = getelementptr inbounds nuw %struct.array, ptr %2, i32 0, i32 0
  %4 = call noalias ptr @malloc(i64 noundef 10) #5
  store ptr %4, ptr %3, align 8
  %5 = getelementptr inbounds nuw %struct.array, ptr %2, i32 0, i32 1
  store i64 10, ptr %5, align 8
  %6 = getelementptr inbounds nuw %struct.array, ptr %2, i32 0, i32 2
  store i64 0, ptr %6, align 8
  %7 = call i32 (ptr, ...) @printf(ptr noundef @.str, i64 noundef 1)
  ret i32 0
}

; Function Attrs: nounwind allocsize(0)
declare noalias ptr @malloc(i64 noundef) #2

declare i32 @printf(ptr noundef, ...) #3

attributes #0 = { noinline nounwind optnone sspstrong uwtable "frame-pointer"="all" "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #1 = { nounwind allocsize(1) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #2 = { nounwind allocsize(0) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #3 = { "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #4 = { nounwind allocsize(1) }
attributes #5 = { nounwind allocsize(0) }

!llvm.module.flags = !{!0, !1, !2, !3, !4}
!llvm.ident = !{!5}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{i32 7, !"frame-pointer", i32 2}
!5 = !{!"clang version 22.1.8"}
!6 = distinct !{!6, !7}
!7 = !{!"llvm.loop.mustprogress"}
