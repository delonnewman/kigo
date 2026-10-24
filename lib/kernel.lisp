(defpackage :kigo
  (:use :cl)
  (:export #:puts))

(in-package :kigo)

(defun puts (string) (print string))
