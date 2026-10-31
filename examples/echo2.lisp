(load "/Users/delon/Projects/Personal/kigo/lib/kernel.lisp")

(defun main ()
  (progn (kigo:gets) (kigo:puts *rb-topic-variable*))
  (sb-ext:exit :code 0))
