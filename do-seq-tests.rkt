#lang racket

(require "do-sequence.rkt"
         "fast-sequence-filter.rkt"
         "fast-sequence-map.rkt"
         racket/match
         rackunit)

(define (counter)
  (define n 0)
  (lambda ([d 1]) (set! n (+ d n)) n))

(define srcs `(([(in-list (list 1 2 3)) (list 1 2 3) (in-range 5) (in-value 1) (+ 0 5) (in-vector (vector 3 5 7))
                 (fast-sequence-map add1 (list 2 3 4)) (in-producer (counter) (lambda (x) (> x 10)))]
                [,(lambda (x) #t) ,(lambda (x) `(even? ,x)) ,(lambda (x) `(< ,x 5)) ,(lambda (x) `(> ,x 1))])
               ([(in-list (list #\a #\b #\c)) (in-string "hello") (fast-sequence-filter char? (in-list #\4 1 #\f 5))
                 (in-port read-char (open-input-string "a1b2c3"))]
                [,(lambda (x) #t) ,(lambda (x) `(char-alphabetic? ,x)) ,(lambda (x) `(char<? ,x #\b))])))

(define seq-when-pairs*
  (for*/list ([l (in-list srcs)]
              [s (in-list (car l))]
              [w (in-list (cadr l))])
    (list s w)))

(define (merges seq1 seq2)
  (for*/list ([sw1 (in-list seq1)]
              [sw2 (in-list seq2)])
    `((in-merge (in-protect ,(car sw1)) (in-protect ,(car sw2)))
      ,(lambda (x y) `(and ,((cadr sw1) x) ,((cadr sw2) y))))))

(define seq-when-pairs  
  (append seq-when-pairs*
          (merges seq-when-pairs* seq-when-pairs*)))

(define (make-test sw1 . sws)
  (define (make-ids sw ids)
    (match (car sw)
      [(list* 'in-merge rest) ids]
      [e (list (car ids))]))
  (define (bind-when sw ids)
    (let ([ids* (make-ids sw ids)])
      (values `[,ids* ,(car sw)] (apply (cadr sw) ids*))))
  (define o (open-output-string))
  (cond
    [(empty? sws)
     (let*-values ([(b1 w1) (bind-when sw1 '(x y))]
                   [(ids) (car b1)]
                   [(do/seq) `(for/list ([x (do/sequence (,b1 #:when ,w1) (list ,@ids))]) x)])
       `(check-equal?
         ,do/seq
         (for/list ([x (for/list (,b1 #:when ,w1) (list ,@ids))]) x)
         ,(begin
            (display do/seq o)
            (get-output-string o))))]
    [else
     (let*-values ([(b1 w1) (bind-when sw1 '(x y))]
                   [(b2 w2) (bind-when (car sws) '(z w))]
                   [(ids) (car b2)]
                   [(do/seq)`(for/list ([x (do/sequence (,b1 #:when ,w1 ,b2 #:when ,w2)
                                             (list ,@ids))])
                               x)])
       `(check-equal?
         ,do/seq
         (for/list ([x (for/list (,b1 #:when ,w1 ,b2 #:when ,w2) (list ,@ids))]) x)
         ,(begin
            (display do/seq o)
            (get-output-string o))))]))

(define seq-when-pairs2
  (for*/list ([s (in-list (caar srcs))]
              [w (in-list (cadar srcs))])
    (list s w)))

(define seq-when-pairs3*
  (for*/list ([s (in-list '((in-range x)))]
              [w (in-list (cadar srcs))])
    (list s w)))

(define seq-when-pairs3  
  (append seq-when-pairs3*
          (merges seq-when-pairs3* seq-when-pairs*)))

(define (run-tests1 ns)
  (for* ([sw (in-list seq-when-pairs)])
    (eval (make-test sw) ns)))

(define (run-tests2 ns)
  (for* ([sw1 (in-list seq-when-pairs)]
         [sw2 (in-list seq-when-pairs)])
    (eval (make-test sw1 sw2) ns)))

(define (run-tests3 ns)
  (for* ([sw1 (in-list seq-when-pairs2)]
         [sw2 (in-list seq-when-pairs3)])
    (eval (make-test sw1 sw2) ns)))

(define (run-tests ns)
  (begin
    (run-tests1 ns)
    (run-tests2 ns)
    (run-tests3 ns)))

(define-namespace-anchor a)
(define ns (namespace-anchor->namespace a))
(eval (make-test (cadr seq-when-pairs)) ns)

(run-tests ns)