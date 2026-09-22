%array = type {ptr,i64,i64}
declare ptr @realloc(ptr, i64)
declare ptr @calloc(i64, i64)
declare i32 @putchar(i32)
declare i32 @getchar()
declare void @memset(ptr, i32, i64)
@tape = global %array zeroinitializer
define void @moveTo(i64 %position) {
entry: br label %loop
loop:
    %capacity_ptr = getelementptr %array, ptr @tape, i32 0, i32 1
    %capacity = load i64, ptr %capacity_ptr
    %cond = icmp ule i64 %capacity, %position
    br i1 %cond, label %body, label %exit
body:
    %old_capacity = load i64, ptr %capacity_ptr
    %new_capacity = mul i64 %old_capacity, 2
    store i64 %new_capacity, ptr %capacity_ptr
    %content_ptr = getelementptr %array, ptr @tape, i32 0, i32 0
    %content = load ptr, ptr %content_ptr
    %new_content = call ptr @realloc(ptr %content, i64 %new_capacity)
    store ptr %new_content, ptr %content_ptr
    %new_area = getelementptr i8, ptr %new_content, i64 %old_capacity
    %new_size = sub i64 %new_capacity, %old_capacity
    call ptr @memset(ptr %new_area, i32 0, i64 %new_size)
    br label %loop
exit:
    %pointer_ptr = getelementptr %array, ptr @tape, i32 0, i32 2
    store i64 %position, ptr %pointer_ptr
    ret void
}
define void @initArray() {
    %capacity_ptr = getelementptr %array, ptr @tape, i32 0, i32 1
    store i64 10, ptr %capacity_ptr
    %pointer_ptr = getelementptr %array, ptr @tape, i32 0, i32 2
    store i64 0, ptr %pointer_ptr
    %content = call ptr @calloc(i64 10, i64 1)
    %content_ptr = getelementptr %array, ptr @tape, i32 0, i32 0
    store ptr %content, ptr %content_ptr
    ret void
}
define ptr @arrayGetPtr() {
  %2 = getelementptr %array, ptr @tape, i32 0, i32 0
  %3 = load ptr, ptr %2
  %4 = getelementptr %array, ptr @tape, i32 0, i32 2
  %5 = load i64, ptr %4
  %6 = getelementptr i8, ptr %3, i64 %5
  ret ptr %6
}
define i32 @main() {
  call void @initArray()
  %pointer = alloca i64
  store i64 0, ptr %pointer

; add
  %add6 = call ptr @arrayGetPtr()
  %add7 = load i8, ptr %add6
  %add8 = add i8 %add7, 1
  store i8 %add8, ptr %add6
; end add

; move
  %move5 = getelementptr %array, ptr @tape, i32 0, i32 2
  %move6 = load i64, ptr %move5
  %move7 = add i64 %move6, 11
  call void @moveTo(i64 %move7)
; end move
  
; getchar
  %getchar6 = call ptr @arrayGetPtr()
  %getchar9 = call i32 @getchar()
  %getchar10 = trunc i32 %getchar9 to i8
  store i8 %getchar10, ptr %getchar6
; end getchar
  
; putchar
  %putchar6 = call ptr @arrayGetPtr()
  %putchar7 = load i8, ptr %putchar6
  %putchar8 = zext i8 %putchar7 to i32
  call i32 @putchar(i32 %putchar8)
; end putchar
  
; loop
  br label %loopb15
loopb15:
  %loop6 = call ptr @arrayGetPtr()
  %loop7 = load i8, ptr %loop6
  %loop8 = icmp ne i8 %loop7, 0
  br i1 %loop8, label %loopb16, label %loopb17
loopb16:
  
  br label %loopb15
loopb17:
; end loop  
  call i32 @putchar(i32 10)
  ret i32 0
}
