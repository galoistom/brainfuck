#!/bin/env racket
#lang typed/racket/base
(require racket/match)
(require racket/system)
(require racket/file)
(require "my-macro.rkt")

(struct bfAdd ((num : Integer)))
(struct bfMove ((num : Integer)))
(struct bfIn ())
(struct bfOut ())
(struct bfStart ())
(struct bfLoop ((content : (Listof bfNode))))
(define-type bfNode (Rec T (U bfAdd bfMove bfIn bfOut bfLoop bfStart)))

;; parsing
(: parse-node (-> (Listof Char) (Pairof (Listof bfNode) (Listof Char))))
(define (parse-node code)
  (let loop ((src : (Listof Char) code) (ast : (Listof bfNode) '()))
    (if (null? src)
        (cons (reverse ast) '())
        (case (car src)
          ((#\+) (match ast
                   ((cons (bfAdd n) rest) (loop (cdr src) (cons (bfAdd (+ 1 n)) rest)))
                   (_ (loop (cdr src) (cons (bfAdd 1) ast)))))
          ((#\-) (match ast
                   ((cons (bfAdd n) rest) (loop (cdr src) (cons (bfAdd (- n 1)) rest)))
                   (_ (loop (cdr src) (cons (bfAdd -1) ast)))))
          ((#\<) (match ast
                   ((cons (bfMove n) rest) (loop (cdr src) (cons (bfMove (- n 1)) rest)))
                   (_ (loop (cdr src) (cons (bfMove -1) ast)))))
          ((#\>) (match ast
                   ((cons (bfMove n) rest) (loop (cdr src) (cons (bfMove (+ 1 n)) rest)))
                   (_ (loop (cdr src) (cons (bfMove 1) ast)))))
          ((#\,) (loop (cdr src) (cons (bfIn) ast)))
          ((#\.) (loop (cdr src) (cons (bfOut) ast)))
          ((#\[) (match-let (((cons inner-nodes rest) (parse-node (cdr src))))
                   (if (and (not (null? rest)) (char=? (car rest) #\]))
                       (loop (cdr rest) (cons (bfLoop inner-nodes) ast))
                       (error 'parse "Unmatched '[': bracket not closed"))))
          ((#\]) (cons (reverse ast) src))
          (else (loop (cdr src) ast))))))

(: parse (-> (Listof Char) (Listof bfNode)))
(define (parse code)
  (match-let (((cons ast rest) (parse-node code)))
    (if (null? rest)
        (let clear ((a ast) (p : (Listof bfNode) '()))
          (if (null? a) (reverse p)
              (match a
                ((cons (bfAdd 0) rest) (clear rest p))
                ((cons (bfMove 0) rest) (clear rest p))
                ((cons (bfLoop loop) rest)
                 (clear rest (cons (bfLoop (clear loop '())) p)))
                ((cons head rest) (clear rest (cons head p))))))
        (error 'parse "Unmatched ']': bracket not closed"))))

;; eval
(struct Tape ((content : Bytes) (pointer : Integer)))
(: Tape-current (-> Tape Byte))
(define (Tape-current t) (bytes-ref (Tape-content t) (Tape-pointer t)))

(: TapeSet (-> Tape Byte Tape))
(define (TapeSet t n) (bytes-set! (Tape-content t) (Tape-pointer t) n) t)

(: TapeAdd (-> Tape Integer Tape))
(define (TapeAdd t n)
  (TapeSet t (assert (modulo (+ (Tape-current t) n) 256) byte?)))

(: TapeMove (-> Tape Integer Tape))
(define (TapeMove t n)
  (let ((new-pos : Integer (+ (Tape-pointer t) n))
        (new-con : Bytes (Tape-content t)))
    (when (< new-pos 0) (error "too left"))
    (while (<= (bytes-length new-con) new-pos)
      (let ((temp (make-bytes (* 2 (bytes-length new-con)) 0)))
        (bytes-copy! temp 0 new-con)
        (set! new-con temp)))
    (Tape new-con new-pos)))

(: eval-node (-> (Listof bfNode) Tape Tape))
(define (eval-node tokens t)
  (let loop ((tape t) (ast tokens))

    (if (null? ast) tape
        (let ((head (car ast)) (rest (cdr ast)))
          (match head
            ((bfAdd n) (loop (TapeAdd tape n) rest))
            ((bfMove n) (loop (TapeMove tape n) rest))
            ((bfIn)
             (define ch (read-char))
             (define byte-val (if (eof-object? ch) 0 (char->integer ch)))
             (loop (TapeSet tape (assert byte-val byte?)) rest))
            ((bfOut)
             (display (integer->char (Tape-current tape))) (loop tape rest))
            ((bfLoop body)
             (if (= (Tape-current tape) 0)
                 (loop tape rest)
                 (loop (eval-node body tape) ast))))))))

(: eval-bf (-> (Listof bfNode) Void))
(define (eval-bf tokens) (void (eval-node tokens (Tape (make-bytes 10 0) 0))))

;; compile to C
(define c-preLog : String
  "#include<stdlib.h>\n#include<stdio.h>\n#include<string.h>
typedef struct{char* content;int capacity;int pointer;}array;
void move(array* a,int position){a->pointer+=position;if(a->pointer<0){printf(\"too left\");exit(1);}
while(a->capacity<=a->pointer){a->content=realloc(a->content,2*a->capacity*sizeof(char));
memset(a->content + a->capacity, 0, a->capacity);a->capacity*=2;}}
int main(){array a={.content=calloc(10,sizeof(char)),.capacity=10,.pointer=0,};")
(define c-epiLog : String "\nputchar('\\n');\nfree(a.content);\nreturn 0;}")

(: compile-c-node (-> String (Listof bfNode) String))
(define (compile-c-node str tokens)
  (if (null? tokens)
      str
      (let ((head (car tokens)) (rest (cdr tokens)))
        (match head
          ((bfAdd n) (compile-c-node (format "~aa.content[a.pointer]+=~a;\n" str n) rest))
          ((bfMove n) (compile-c-node (format "~amove(&a,~a);\n" str n) rest))
          ((bfIn) (compile-c-node (format "~aa.content[a.pointer]=getchar();\n" str) rest))
          ((bfOut) (compile-c-node (format "~aputchar(a.content[a.pointer]);\n" str) rest))
          ((bfLoop loop) (compile-c-node (format "~awhile(a.content[a.pointer]!=0){~a}\n"
                                               str (compile-c-node "" loop)) rest))))))

(: compile-c-bf (-> String (Listof bfNode) Void))
(define (compile-c-bf name tokens)
  (let ((s (string-append c-preLog (compile-c-node "" tokens) c-epiLog)))
    (call-with-output-file (string-append name ".c") #:exists 'replace
      (lambda ((out : Output-Port)) (display s out)))
    (if (system (string-append "cc " name ".c -o " name))
        (begin (printf "compiled cussessfully to: ~a" name)
               (delete-file (string->path (string-append name ".c"))))
        (error "failed to compile"))))

;; compile to llvm
(: compile-llvm-node (-> String (Listof bfNode) Integer (Values String Integer)))
(define (compile-llvm-node str tokens num)
  (if (null? tokens)
      (values str num)
      (let ((head (car tokens)) (rest (cdr tokens)))
        (match head
          ((bfAdd n) (compile-llvm-node (string-append str (llvm-add n num)) rest (+ num 3)))
          ((bfMove n) (compile-llvm-node (string-append str (llvm-move n num)) rest (+ num 3)))
          ((bfIn) (compile-llvm-node (string-append str (llvm-in num)) rest (+ num 3)))
          ((bfOut) (compile-llvm-node (string-append str (llvm-out num)) rest (+ num 3)))
          ((bfLoop loop) (let-values (((s n) (compile-llvm-node "" loop (+ num 3))))
                           (compile-llvm-node (string-append str (llvm-loop s num)) rest n)))))))

(: llvm-add (-> Integer Integer String))
(define (llvm-add n num)
  (format "\n  %p~a = call ptr @arrayGetPtr()
  %p~a = load i8, ptr %p~a
  %p~a = add i8 %p~a, ~a
  store i8 %p~a, ptr %p~a" num (+ num 1) num (+ num 2) (+ num 1) n (+ num 2) num))
(: llvm-move (-> Integer Integer String))
(define (llvm-move n num)
  (format "\n  %p~a = getelementptr %array, ptr @tape, i32 0, i32 2
  %p~a = load i64, ptr %p~a
  %p~a = add i64 %p~a, ~a
  call void @moveTo(i64 %p~a)" num (+ num 1) num (+ num 2) (+ num 1) n (+ num 2)))
(: llvm-in (-> Integer String))
(define (llvm-in num)
  (format "\n   %p~a = call ptr @arrayGetPtr()
  %p~a = call i32 @getchar()
  %p~a = trunc i32 %p~a to i8
  store i8 %p~a, ptr %p~a" num (+ num 1) (+ num 2) (+ num 1) (+ num 2) num))
(: llvm-out (-> Integer String))
(define (llvm-out num)
  (format "\n  %p~a = call ptr @arrayGetPtr()
  %p~a = load i8, ptr %p~a
  %p~a = zext i8 %p~a to i32
  call i32 @putchar(i32 %p~a)" num (+ num 1) num (+ num 2) (+ num 1) (+ num 2)))
(: llvm-loop (-> String Integer String))
(define (llvm-loop str num)
  (format "\n  br label %b~a\nb~a:
  %p~a = call ptr @arrayGetPtr()
  %p~a = load i8, ptr %p~a
  %p~a = icmp ne i8 %p~a, 0
  br i1 %p~a, label %b~a, label %b~a
b~a:\n~a\nbr label %b~a\nb~a:" num num num (+ num 1) num (+ num 2) (+ num 1)
          (+ num 2) (+ num 1) (+ num 2) (+ num 1) str num (+ num 2)))

(define llvm-preLog : String
  "%array = type {ptr,i64,i64}
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
    ret void\n}
define void @initArray() {
entry:
    %capacity_ptr = getelementptr %array, ptr @tape, i32 0, i32 1
    store i64 2, ptr %capacity_ptr
    %pointer_ptr = getelementptr %array, ptr @tape, i32 0, i32 2
    store i64 0, ptr %pointer_ptr
    %content = call ptr @calloc(i64 2, i64 1)
    %content_ptr = getelementptr %array, ptr @tape, i32 0, i32 0
    store ptr %content, ptr %content_ptr
    ret void\n}
define ptr @arrayGetPtr() {
    %2 = getelementptr %array, ptr @tape, i32 0, i32 0
    %3 = load ptr, ptr %2
    %4 = getelementptr %array, ptr @tape, i32 0, i32 2
    %5 = load i64, ptr %4
    %6 = getelementptr i8, ptr %3, i64 %5
    ret ptr %6\n}
define i32 @main() {
    call void @initArray()
    %pointer = alloca i64
    store i64 0, ptr %pointer\n")
(define llvm-epiLog : String "\n  call i32 @putchar(i32 10)\nret i32 0\n}")

(: compile-llvm-bf (-> String (Listof bfNode) Void))
(define (compile-llvm-bf name tokens)
  (define-values (str _) (compile-llvm-node "" tokens 1))
  (let ((s (string-append llvm-preLog str llvm-epiLog)))
    (call-with-output-file (string-append name ".ll") #:exists 'replace
      (lambda ((out : Output-Port)) (display s out)))
    (if (system (string-append "clang " name ".ll -o " name))
        (begin (printf "compiled cussessfully to: ~a" name)
               (delete-file (string->path (string-append name ".ll"))))
        (error "failed to compile"))))

;; main
(: main (-> Void))
(define (main)
  (let ((arguments (vector->list (current-command-line-arguments))))
    (when (null? arguments) (set! arguments (list "-h")))
    (: compile-bf (-> (-> String (Listof bfNode) Void) Void))
    (define (compile-bf func)
      (let ((filename "output") (args arguments))
        (while (->> args cdr (equal? '()) not)
          (when (or (equal? (car args) "--output") (equal? (car args) "-o"))
            (set! filename (cadr args)))
          (set! args (cdr args)))
        (->> arguments cadr string->path file->string string->list parse (func filename))))
    (case (car arguments)
      (("--eval" "-e") (->> arguments cadr string->list parse eval-bf))
      (("--file" "-f") (->> arguments cadr string->path file->string string->list parse eval-bf))
      (("--llvm" "-l") (compile-bf compile-llvm-bf))
      (("--cc"   "-c")  (compile-bf compile-c-bf))
      (else
       (display "usage: brainfuck [option] <file.bf>
      -e/--eval:    to evaluate a single sentence
      -f/--file:    to run the code with interpreter
      -c/--cc:      to compile the code to executable with cc
      -l/--llvm:    to compile the code to executable with llvm
      -o/--output:  to name the compile output
      -h/--help:    to get help"))))
  (newline))
(main)
