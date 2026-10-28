(defpackage :kigo
  (:use :cl)
  (:export #:puts #:gets))

(in-package :kigo)

(defun puts (string) (print string))

(defun gets () (read-line))
