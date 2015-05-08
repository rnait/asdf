(defsystem "asdf-tools"
  :description "tools to build, test, maintain and release ASDF itself"
  :depends-on ((:version "asdf" "3.1.2")
               (:version "inferior-shell" "2.0.2")
               (:version "lisp-invocation" "1.0.2")
               (:version "cl-ppcre" "2.0.4")
               (:version "optima.ppcre" "1.0")
               (:feature :sbcl "sb-introspect"))
  :components
  ((:file "package")
   (:file "failure" :depends-on ("package"))
   (:file "main" :depends-on ("failure"))
   (:file "pathnames" :depends-on ("package"))
   (:file "version" :depends-on ("failure"))
   (:file "invoke-lisp" :depends-on ("package"))
   (:file "test-environment" :depends-on ("pathnames" "invoke-lisp" "main"))
   (:file "build" :depends-on ("test-environment"))
   (:file "git" :depends-on ("test-environment"))
   (:file "test-basic" :depends-on ("test-environment"))
   (:file "test-scripts" :depends-on ("test-environment"))
   (:file "test-upgrade" :depends-on ("test-environment" "git"))
   (:file "test-all" :depends-on ("test-environment"))
   (:file "installation" :depends-on ("test-environment"))
   (:file "release" :depends-on ("version" "test-environment" "git"))))