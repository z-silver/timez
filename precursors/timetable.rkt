#!/usr/bin/env racket
#lang racket/base
;; This is free and unencumbered software released into the public domain.
;; For more information, please refer to <https://unlicense.org/>

;; This is a script for computing work time based on a start/end log.
;; Said log is meant to be written out by hand as you work, and each line
;; in the log has the following format:

;; <start-time>-<end-time> <project> -- <description>
;; example: 1130-1200 cookbook -- trying out new recipe #2

;; The project label is optional, in which case the following separator
;; is omitted and the label is assumed to be misc.

;; Lines not conforming to that format are comments.

(require racket/string racket/format
  csv-writing) ; make sure this is installed before running the script

(define (valid-line? s)
  ; TODO: validate the actual times, make sure the latter is actually later
  (and (>= (string-length s) 9)
    (let [(t-start (string->list (substring s 0 4)))
          (t-end (string->list (substring s 5 9)))]
      (and (andmap char-numeric? t-start)
        (andmap char-numeric? t-end)))))

(define (line->entry s)
  (define timing (substring s 0 9))
  (define-values [start end]
    (apply values (map timestamp->minutes (string-split timing "-"))))
  (define details (string-trim (substring s 9)))
  (define entry (map string->immutable-string (string-split details " -- ")))
  (define-values [project description]
    (let [(entry (if (null? entry) '("") entry))]
      (if (null? (cdr entry))
        (values 'misc (car entry))
        (values (string->symbol (car entry)) (cadr entry)))))
  (define duration (- end start))
  (list project description duration (minutes->hours duration)))

(define (minutes->hours minutes)
  (define-values [hours* mins*] (quotient/remainder minutes 60))
  (define hours (~a hours*))
  (define mins (~a mins* #:width 2 #:align 'right #:left-pad-string "0"))
  (string-append-immutable hours ":" mins))

(define (timestamp->minutes ts)
  (define hours (string->number (substring ts 0 2)))
  (define minutes (string->number (substring ts 2)))
  (+ (* hours 60) minutes))

(define (parse-lines)
  (define line (read-line))
  (if (eof-object? line) '()
    (if (valid-line? line)
      (cons (line->entry line) (parse-lines))
      (parse-lines))))

(define (add-time entry times)
  (define project (car entry))
  (define minutes (caddr entry))
  (hash-update times project (lambda [t] (+ t minutes)) 0))

(define (total-times table)
  (foldl add-time #hashalw() table))

(display-table
  (let* [(table (parse-lines))
         (totals (total-times table))
         (total-table
           (cons
             (let [(minutes (for/fold [(sum 0)]
                                      [(t (in-hash-values totals))]
                              (+ sum t)))]
               (list 'total minutes (minutes->hours minutes)))
             (for/list [(p (in-hash-pairs totals))]
               (list (car p) (cdr p) (minutes->hours (cdr p))))))]
    (append
      (cons '(project "total duration (minutes)" "total duration (hours)") total-table)
      '(())
      (cons '(project description "duration (minutes)" "duration (hours)") table))))
