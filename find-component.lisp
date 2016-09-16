;;;; -------------------------------------------------------------------------
;;;; Finding components

(uiop/package:define-package :asdf/find-component
  (:recycle :asdf/find-component :asdf)
  (:use :uiop/common-lisp :uiop :asdf/upgrade :asdf/cache
   :asdf/component :asdf/system :asdf/find-system)
  (:export
   #:find-component
   #:resolve-dependency-name #:resolve-dependency-spec
   #:resolve-dependency-combination
   ;; Conditions
   #:missing-component #:missing-component-of-version #:retry
   #:missing-dependency #:missing-dependency-of-version
   #:missing-requires #:missing-parent
   #:missing-required-by #:missing-version))
(in-package :asdf/find-component)

;;;; Missing component conditions

(with-upgradability ()
  (define-condition missing-component-of-version (missing-component)
    ((version :initform nil :reader missing-version :initarg :version)))

  (define-condition missing-dependency (missing-component)
    ((required-by :initarg :required-by :reader missing-required-by)))

  (defmethod print-object ((c missing-dependency) s)
    (format s (compatfmt "~@<~A, required by ~A~@:>")
            (call-next-method c nil) (missing-required-by c)))

  (define-condition missing-dependency-of-version (missing-dependency
                                                   missing-component-of-version)
    ())

  (defmethod print-object ((c missing-component) s)
    (format s (compatfmt "~@<Component ~S not found~@[ in ~A~]~@:>")
            (missing-requires c)
            (when (missing-parent c)
              (coerce-name (missing-parent c)))))

  (defmethod print-object ((c missing-component-of-version) s)
    (format s (compatfmt "~@<Component ~S does not match version ~A~@[ in ~A~]~@:>")
            (missing-requires c)
            (missing-version c)
            (when (missing-parent c)
              (coerce-name (missing-parent c))))))


;;;; Finding components

(with-upgradability ()
  (defgeneric* (find-component) (base path &key registered)
    (:documentation "Find a component by resolving the PATH starting from BASE parent"))
  (defgeneric resolve-dependency-combination (component combinator arguments))

  (defmethod find-component ((base string) path &key registered)
    (if-let ((s (if registered
                    (registered-system base)
                    (find-system base nil))))
      (find-component s path :registered registered)))

  (defmethod find-component ((base symbol) path &key registered)
    (cond
      (base (find-component (coerce-name base) path :registered registered))
      (path (find-component path nil :registered registered))
      (t    nil)))

  (defmethod find-component ((base cons) path &key registered)
    (find-component (car base) (cons (cdr base) path) :registered registered))

  (defmethod find-component ((parent parent-component) (name string) &key registered)
    (declare (ignorable registered))
    (compute-children-by-name parent :only-if-needed-p t)
    (values (gethash name (component-children-by-name parent))))

  (defmethod find-component (base (name symbol) &key registered)
    (if name
        (find-component base (coerce-name name) :registered registered)
        base))

  (defmethod find-component ((c component) (name cons) &key registered)
    (find-component (find-component c (car name) :registered registered)
                    (cdr name) :registered registered))

  (defmethod find-component ((base t) (actual component) &key registered)
    (declare (ignorable registered))
    actual)

  (defun resolve-dependency-name (component name &optional version)
    (loop
      (restart-case
          (return
            (let ((comp (find-component (component-parent component) name)))
              (unless comp
                (error 'missing-dependency
                       :required-by component
                       :requires name))
              (when version
                (unless (version-satisfies comp version)
                  (error 'missing-dependency-of-version
                         :required-by component
                         :version version
                         :requires name)))
              comp))
        (retry ()
          :report (lambda (s)
                    (format s (compatfmt "~@<Retry loading ~3i~_~A.~@:>") name))
          :test
          (lambda (c)
            (or (null c)
                (and (typep c 'missing-dependency)
                     (eq (missing-required-by c) component)
                     (equal (missing-requires c) name))))
          (unless (component-parent component)
            (let ((name (coerce-name name)))
              (unset-asdf-cache-entry `(find-system ,name))
              (unset-asdf-cache-entry `(locate-system ,name))))))))


  (defun resolve-dependency-spec (component dep-spec)
    (let ((component (find-component () component)))
      (if (atom dep-spec)
          (resolve-dependency-name component dep-spec)
          (resolve-dependency-combination component (car dep-spec) (cdr dep-spec)))))

  (defmethod resolve-dependency-combination (component combinator arguments)
    (parameter-error (compatfmt "~@<In ~S, bad dependency ~S for ~S~@:>")
                     'resolve-dependency-combination (cons combinator arguments) component))

  (defmethod resolve-dependency-combination (component (combinator (eql :feature)) arguments)
    (when (featurep (first arguments))
      (resolve-dependency-spec component (second arguments))))

  (defmethod resolve-dependency-combination (component (combinator (eql :version)) arguments)
    (resolve-dependency-name component (first arguments) (second arguments)))) ;; See lp#527788

