#lang racket

(provide ->> while todo)
(define-syntax ->>
  (syntax-rules ()
    ((_ x) x)
    ((_ x (fn args ...) rest ...)
     (->> (fn args ... x) rest ...))
    ((_ x fn rest ...)
     (->> (fn x) rest ...))))

(define-syntax-rule (while condition action ...)
  (let loop ()
    (when condition
      action ...
      (loop))))

(define-syntax (todo stx)
  (syntax-case stx ()
    [(_ (name params ...) body ...)
     (let* ((name-str (symbol->string (syntax->datum #'name)))
            (todo-str (string-append "todo-" name-str))
            (todo-sym (string->symbol todo-str)))
       (with-syntax ([quoted (datum->syntax #'name `(quote ,todo-sym))])
         #'(define (name params ...)
             quoted)))]))
