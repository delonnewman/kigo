(defpackage :kigo
  (:use :cl)
  (:export #:puts #:gets))

(in-package :kigo)

(defparameter *rb-global-context* nil
  "Ruby's $_ variable")

(defun puts (object)
  "Equivalent to
```ruby
$stdout.puts
```'"
  (princ
   (if (and (stringp object)
            (char= #\Newline (last-elem object)))
       object
       (concatenate 'string object (string #\Newline)))
   *standard-output*)
  nil)

(defun last-elem (array)
  (aref array (1- (array-total-size array))))

(defun gets ()
  "gets(sep=$/ [, getline_args]) → string or nil
gets(limit [, getline_args]) → string or nil
gets(sep, limit [, getline_args]) → string or nil

Returns (and assigns to $_) the next line from the list of files in ARGV (or $*),
or from standard input if no files are present on the command line. Returns nil
at end of file. The optional argument specifies the record separator. The
separator is included with the contents of each record. A separator of nil reads
the entire contents, and a zero-length separator reads the input one paragraph at
a time, where paragraphs are divided by two consecutive newlines. If the first
argument is an integer, or optional second argument is given, the returning
string would not be longer than the given value in bytes. If multiple filenames
are present in ARGV, gets(nil) will read the contents one file at a time."
  (multiple-value-bind (line missing-newline-p)
      (read-line *standard-input* nil nil)
    (setf *rb-global-context*
          (cond ((null line) nil)
                (missing-newline-p line)
                (t (concatenate 'string line (string #\Newline)))))))
