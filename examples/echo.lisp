(load "/Users/delon/Projects/Personal/kigo/lib/kernel.lisp")

(defun main ()
  (progn (kigo:puts (kigo:gets)))
  (sb-ext:exit :code 0))
