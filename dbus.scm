;;;; dbus.scm

(module dbus
    (make-context
     send
     call
     make-method-proxy
     register-signal-handler
     register-method
     enable-polling-thread!
     poll-for-message
     discover-services
     discover-api-xml
     dbus-service
     session-bus
     system-bus
     starter-bus
     known-bus-count
     bus-name
     ;; register-path ;; disabled for now due to https://bugs.call-cc.org/ticket/850
     unsupported-type?
     unsupported-type-signature
     default-signal-handler
     printing-signal-handler
     dump-callback-table

     make-variant
     variant?
     variant-data
     auto-unbox-variants

     make-struct
     struct?
     struct-ref
     struct-set!
     auto-unbox-structs
     vector->struct
     struct->vector

     string->object-path
     object-path?
     object-path->string
     auto-unbox-object-paths)

(import scheme chicken extras
        (except foreign foreign-declare)
        foreigners
        easyffi
        miscmacros)

(use srfi-18)

#>
#include <dbus/dbus.h>
#include <stdbool.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>

static DBusError err;
<#

;; A disjoint type to represent any kind of dbus data type
;; which this egg so far does not support.  The signature
;; is the ASCII string to represent that type on-the-wire.
(define-record-type unsupported-type
  (make-unsupported-type signature)
  unsupported-type?
  (signature unsupported-type-signature))

(define-record-printer (unsupported-type d out)
  (fprintf out "#<unsupported-type ~s>" (unsupported-type-signature d)))


;; Object path is a string which is a dbus path
(define-record-type object-path
  (string->object-path str)
  object-path?
  (str object-path->string))

(define-record-printer (object-path d out)
  (fprintf out "#<object-path ~s>" (object-path->string d)))

(define auto-unbox-object-paths (make-parameter #f))


;; Scheme is a dynamically typed language, so fundamentally we don't
;; have a use for the "variant" concept; but since dbus has a variant type,
;; we need a way of representing one when preparing a message for marshalling.
(define-record-type variant
  (make-variant #!optional data)
  variant?
  (data variant-data))

(define-record-printer (variant v out)
  (fprintf out "#,(variant ~S)" (variant-data v)))

;; If unboxing is turned on, when a "call"ed dbus service method
;; returns a variant, it will look as if it was not packaged in a variant at all.
;; By default this feature is turned off, in the interest of having a
;; representation that is the same as you will need to build when
;; you want to send (marshall) a dbus message.  But probably
;; you want to turn it on for convenience, if you don't care to know
;; about this low-level detail.
(define auto-unbox-variants (make-parameter #f))


;; A DBus struct is represented as a vector, but it's tagged for marshalling
;; record definition as just a wrapped vector
(define-record-type struct
  (vector->struct data)
  struct?
  (data struct->vector))

(define (make-struct . fields) (vector->struct (list->vector fields)))
(define (struct-ref struct idx) (vector-ref (struct->vector struct) idx))
(define (struct-set! struct idx val) (vector-set! (struct->vector struct) idx val))

(define-record-printer (struct v out)
  (fprintf out "#,(struct ~S)" (struct->vector v)))

;; If unboxing is turned on, when a "call"ed dbus service method
;; returns a struct, it will look like a vector instead.  This is
;; convenient if you know what to expect, but otherwise you will
;; have some difficulty to distinguish a struct from an array.
;; By default this feature is turned off, in the interest of having a
;; representation that is the same as you will need to build when
;; you want to send (marshall) a dbus message.
(define auto-unbox-structs (make-parameter #f))


;; Would want to do this:
;; (define-foreign-enum (bus (enum "DBusBusType"))
;;   (session-bus DBUS_BUS_SESSION)
;;   (system-bus DBUS_BUS_SYSTEM)
;;   (starter-bus DBUS_BUS_STARTER))
;; but because that enum is typedef'd, chicken has a problem with it.

(define-foreign-type bus int) ; really "DBusBusType"
(define session-bus (foreign-value DBUS_BUS_SESSION int))
(define system-bus (foreign-value DBUS_BUS_SYSTEM int))
(define starter-bus (foreign-value DBUS_BUS_STARTER int))
(define dbus-service (foreign-value DBUS_SERVICE_DBUS c-string))
(define known-bus-count (+ 1 (max session-bus system-bus starter-bus)))
(define (bus-name bus)
  (cond
   ((eq? bus session-bus) (format "session bus (~a)" session-bus))
   ((eq? bus system-bus) (format "system bus (~a)" system-bus))
   (else (format "bus ~a" (car bus)))))

(define-foreign-type handler-result int) ;; really "DBusHandlerResult"
(define result-handled (foreign-value DBUS_HANDLER_RESULT_HANDLED int))
(define result-not-yet-handled (foreign-value DBUS_HANDLER_RESULT_NOT_YET_HANDLED int))
(define result-need-memory (foreign-value DBUS_HANDLER_RESULT_NEED_MEMORY int))

(define name-flag-allow-replacement (foreign-value DBUS_NAME_FLAG_ALLOW_REPLACEMENT int))
(define name-flag-replace-existing (foreign-value DBUS_NAME_FLAG_REPLACE_EXISTING int))
(define name-flag-do-not-queue (foreign-value DBUS_NAME_FLAG_DO_NOT_QUEUE int))

;; DBus simple data types
(define type-invalid (foreign-value DBUS_TYPE_INVALID int))
(define type-byte (foreign-value DBUS_TYPE_BYTE int))
(define type-boolean (foreign-value DBUS_TYPE_BOOLEAN int))
(define type-int16 (foreign-value DBUS_TYPE_INT16 int))
(define type-uint16 (foreign-value DBUS_TYPE_UINT16 int))
(define type-fixnum (foreign-value DBUS_TYPE_INT32 int))
(define type-int32 (foreign-value DBUS_TYPE_INT32 int))
(define type-uint32 (foreign-value DBUS_TYPE_UINT32 int))
(define type-int64 (foreign-value DBUS_TYPE_INT64 int))
(define type-uint64 (foreign-value DBUS_TYPE_UINT64 int))
(define type-double (foreign-value DBUS_TYPE_DOUBLE int))
(define type-flonum (foreign-value DBUS_TYPE_DOUBLE int))
(define type-string (foreign-value DBUS_TYPE_STRING int))
(define type-object-path (foreign-value DBUS_TYPE_OBJECT_PATH int))
(define type-signature (foreign-value DBUS_TYPE_SIGNATURE int))
(define type-array (foreign-value DBUS_TYPE_ARRAY int))
(define type-dict-entry (foreign-value DBUS_TYPE_DICT_ENTRY int))
(define type-dict-entry-begin (foreign-value DBUS_DICT_ENTRY_BEGIN_CHAR int))
(define type-dict-entry-end (foreign-value DBUS_DICT_ENTRY_END_CHAR int))
(define type-variant (foreign-value DBUS_TYPE_VARIANT int))
(define type-struct (foreign-value DBUS_TYPE_STRUCT int))
(define type-struct-begin (foreign-value DBUS_STRUCT_BEGIN_CHAR int))
(define type-struct-end (foreign-value DBUS_STRUCT_END_CHAR int))

(define default-signal-handler (make-parameter #f))

(define (identity a) a)

(define-foreign-type error-ptr (c-pointer "DBusError")
  identity
  (lambda (p)
    (set-finalizer!
     p (lambda (o) ((foreign-lambda void "dbus_error_free" error-ptr) o)))))

(define-foreign-type connection-ptr (c-pointer "DBusConnection"))

(define-foreign-type message-ptr (c-pointer "DBusMessage")
  identity
  (lambda (p)
    (when p
      (set-finalizer!
       p (lambda (o) ((foreign-lambda void "dbus_message_unref" message-ptr) o))))))

(define-foreign-type uint-ptr (c-pointer "dbus_uint32_t"))

(define-foreign-type message-iter-ptr (c-pointer "DBusMessageIter"))
;; from the docs: "DBusMessageIter contains no allocated memory; it need not be freed,
;; and can be copied by assignment or memcpy()."

(define-foreign-type vtable-ptr c-pointer) ;; DBusObjectPathVTable*

(define (discover-services #!key (bus session-bus))
  (let* ((ctxt (make-context bus: bus
                             service: 'org.freedesktop.DBus
                             interface: 'org.freedesktop.DBus
                             path: '/org/freedesktop/DBus))
         (services (call ctxt "ListNames")))
    (and (pair? services) (vector? (car services)) (vector->list (car services)))))

(define msg-path
  (foreign-lambda c-string "dbus_message_get_path" message-ptr))

(define msg-interface
  (foreign-lambda c-string "dbus_message_get_interface" message-ptr))

(define msg-member
  (foreign-lambda c-string "dbus_message_get_member" message-ptr))

(define msg-error-name
  (foreign-lambda c-string "dbus_message_get_error_name" message-ptr))

(define msg-service
  (foreign-lambda c-string "dbus_message_get_destination" message-ptr))

(define-external (C_msg_cb (bus bus) (message-ptr msg)) bool
  (let* ((cb (find-callback bus msg))
         (found (procedure? cb)))
    (when found
      (cb msg))
    found))

(define connections '()) ;; an alist mapping bus to DBusConnection ptrs
(define dbus-error (foreign-value "&err" c-pointer))
;; indices in a "context" vector
(define context-idx-ID 0)
(define context-idx-bus 1)
(define context-idx-service 2)
(define context-idx-path 3)
(define context-idx-interface 4)
(define context-count 0)
(define default-polling-interval 0.01)
(define polling-interval (make-vector known-bus-count 0.01))
(define polling-enabled (make-vector known-bus-count #t))
(define polling-threads (make-vector known-bus-count #f))
;; will become an assoc tree:
;; bus
;;   path
;;     service (unless it's a signal callback)
;;       interface
;;         method
;;           callback-fn
(define callbacks-table `((,system-bus . #f) (,session-bus . #f)))
(define iterm (gensym 'terminiter))

(define (any->string arg)
  (if (string? arg)
      arg
      (if (eq? (void) arg)
          ""
          (format "~a" arg))))

(define (symbol?->string arg)
  (if (symbol? arg)
      (symbol->string arg)
      arg))

(define (string?->symbol arg)
  (if (string? arg)
      (string->symbol arg)
      arg))

(define (ascii->string a) (string (integer->char a)))

(define (vector-for-each fn v)
  (let ((len (vector-length v)))
    (let loop ((i 0))
      (when (< i len)
        (fn i (vector-ref v i))
        (loop (+ 1 i))))))

;; If the assq-list has the given key, replace its value.
;; Else add the key-value pair.
(define (asset! alist key val)
  (let ((pr (assq key alist)))
    (if pr
        (set-cdr! pr val)
        (if (null? (cdar alist))
            (set-car! alist (cons key val))
            (begin
              (set-cdr! alist (cons (car alist) (cdr alist)))
              (set-car! alist (cons key val)))))))

;; The "tree" version of assq: drills down into an assq-tree
;; as directed by the sequence of keys, and returns the value found.
;; #f means not found (so it is not useful to store #f in such a tree).
(define (tassq tree . keys)
  (let ((key-list (if (pair? (car keys)) (car keys) keys)))
    (let loop ((rem-keys key-list)
               (subtree tree))
      (cond
       ((null? rem-keys) subtree)
       ((not subtree) #f)
       (else (loop (cdr rem-keys)
                   (let ((pr (assq (car rem-keys) subtree)))
                     (and (pair? pr) (cdr pr)))))))))

;; The "tree" version of asset!: drills down into an assq-tree
;; as directed by the sequence of keys, making new branches as necessary,
;; and sets the given value as a leaf at that point in the tree.
;; return value is undefined
(define (tasset! tree val . keys)
  (let ((key-list (if (pair? (car keys)) (car keys) keys)))
    (let loop ((rem-keys (cdr key-list))
               (subtree (tassq tree (car key-list)))
               (prev-key (car key-list))
               (prev-subtree tree))
      ;; (printf "rem-keys ~s subtree ~s prev-key ~s prev-subtree ~s~%" rem-keys subtree prev-key prev-subtree)
      (when (and (not subtree) (pair? rem-keys))
        (set! subtree (list (cons (car rem-keys) #f)))
        ;; (printf "   creating subtree ~s within ~s~%" subtree prev-subtree)
        (asset! prev-subtree prev-key subtree)
        ;; (pretty-print prev-subtree)
        )
      (if (null? rem-keys)
          (asset! prev-subtree prev-key val)
          (loop
           (cdr rem-keys)
           (let ((pr (assq (car rem-keys) subtree)))
             (unless (pair? pr)
               (set! pr (cons (car rem-keys) #f))
               (set-cdr! subtree (cons (car subtree) (cdr subtree)))
               (set-car! subtree pr))
             (cdr pr))
           (car rem-keys)
           subtree)))))

(define (dump-callback-table)
  (for-each
   (lambda (bus)
     (printf "~a:~%" (bus-name (car bus)))
     (if (cdr bus)
         (for-each
          (lambda (path)
            (printf "   ~a~%" (car path))
            (for-each
             (lambda (iface)
               (printf "    ~a~%" (car iface)) (pp (cdr iface))) (cdr path)))
          (cdr bus))
         (printf "   no callbacks registered~%")))
   callbacks-table))

(define (printing-signal-handler #!optional port)
  (lambda (context mber args)
    (let ((str (format "failed to find callback for ~a ~a ~a ~a on ~a~%"
                       (vector-ref context context-idx-path)
                       (vector-ref context context-idx-service)
                       (vector-ref context context-idx-interface)
                       mber (bus-name (vector-ref context context-idx-bus)))))
      (if port
          (display str port)
          (display str)))))

(define (next-context-ID) (set! context-count (+ 1 context-count)) context-count)

(define (get-conn bus-type)
  (let ((conn (assq bus-type connections)))
    (if (pair? conn)
        (set! conn (cdr conn))
        (begin
          (set! conn ((foreign-lambda connection-ptr "dbus_bus_get" bus error-ptr)
                      bus-type dbus-error))
          (when conn
            (set! connections (cons (cons bus-type conn) connections)))))
    conn))

(define (conn-or-abort bus-type)
  (or (get-conn bus-type)
      (abort (format "unable to connect to bus ~s~%" bus-type))))

(define (exists-or-abort datum err-str)
  (or datum
      (abort err-str)))

(define (make-signal path interface name)
  ((foreign-lambda message-ptr "dbus_message_new_signal" c-string c-string c-string)
   path interface name))

(define (make-message service path interface method-name)
  ((foreign-lambda message-ptr "dbus_message_new_method_call"
     c-string c-string c-string c-string) service path interface method-name))

(define make-error
  (foreign-lambda* (c-pointer (struct "DBusError")) ()
    "DBusError *err = malloc(sizeof(DBusError));\n"
    "dbus_error_init(err);\n"
    "C_return(err);\n"))

(define free-error!
  (foreign-lambda* void (((c-pointer (struct "DBusError")) err))
    "dbus_error_free(err);"))

(define (raise-dbus-error location err)
  (let ((err-name
         ((foreign-lambda* c-string (((c-pointer (struct "DBusError")) err))
            "C_return(err->name);")
          err))
        (err-message
         ((foreign-lambda* c-string (((c-pointer (struct "DBusError")) err))
            "C_return(err->message);")
          err)))
    (free-error! err)
    (signal
     (make-composite-condition
      (make-property-condition 'dbus-call)
      (make-property-condition
       'exn
       'location location
       'message (string-append "(" err-name "): " err-message))))))

;; todo: garbage-collect this
(define make-iter-append
  (foreign-lambda* message-iter-ptr ((message-ptr msg))
    "DBusMessageIter* iter = malloc(sizeof(DBusMessageIter));\n"
    "dbus_message_iter_init_append (msg, iter);\n"
    "C_return (iter);\n"))

(define iter-append-basic-string
  (foreign-lambda* bool ((message-iter-ptr iter) (c-string v))
    "C_return (dbus_message_iter_append_basic(iter, DBUS_TYPE_STRING, &v));"))

(define iter-append-basic-object-path
  (foreign-lambda* bool ((message-iter-ptr iter) (c-string v))
    "C_return (dbus_message_iter_append_basic(iter, DBUS_TYPE_OBJECT_PATH, &v));"))

(define iter-append-basic-bool
  (foreign-lambda* bool ((message-iter-ptr iter) (bool v))
    "C_return (dbus_message_iter_append_basic(iter, DBUS_TYPE_BOOLEAN, &v));"))

(define iter-append-basic-int
  (foreign-lambda* bool ((message-iter-ptr iter) (int v))
    "C_return (dbus_message_iter_append_basic(iter, DBUS_TYPE_INT32, &v));"))

(define iter-append-basic-double
  (foreign-lambda* bool ((message-iter-ptr iter) (double v))
    "C_return (dbus_message_iter_append_basic(iter, DBUS_TYPE_DOUBLE, &v));"))

(define iter-append-basic-byte
  (foreign-lambda* bool ((message-iter-ptr iter) (int v))
    "C_return (dbus_message_iter_append_basic(iter, DBUS_TYPE_BYTE, &v));"))

(define iter-append-basic-int16
  (foreign-lambda* bool ((message-iter-ptr iter) (int v))
    "C_return (dbus_message_iter_append_basic(iter, DBUS_TYPE_INT16, &v));"))

(define iter-append-basic-uint32
  (foreign-lambda* bool ((message-iter-ptr iter) (unsigned-integer32 v))
    "C_return (dbus_message_iter_append_basic(iter, DBUS_TYPE_UINT32, &v));"))

(define iter-append-basic-uint16
  (foreign-lambda* bool ((message-iter-ptr iter) (unsigned-short v))
    "C_return (dbus_message_iter_append_basic(iter, DBUS_TYPE_UINT16, &v));"))

(define iter-append-basic-int64
  (foreign-lambda* bool ((message-iter-ptr iter) (integer64 v))
    "C_return (dbus_message_iter_append_basic(iter, DBUS_TYPE_INT64, &v));"))

(define iter-append-basic-uint64
  (foreign-lambda* bool ((message-iter-ptr iter) (integer64 v))
    "C_return (dbus_message_iter_append_basic(iter, DBUS_TYPE_UINT64, &v));"))

(define (value-signature val)
  ;; (printf "value-signature ~s~%" val)
  (cond
   ((string? val) (ascii->string type-string))
   ((object-path? val) (ascii->string type-object-path))
   ((fixnum? val) (ascii->string type-fixnum))
   ((flonum? val) (ascii->string type-flonum))
   ((boolean? val) (ascii->string type-boolean))
   ((variant? val) (ascii->string type-variant))
   ((struct? val) (format "~a~a~a" (ascii->string type-struct-begin)
                          (apply string-append
                                 (map value-signature (vector->list (struct->vector val))))
                          (ascii->string type-struct-end)))
   ((vector? val) (format "~a~a" (ascii->string type-array) (value-signature (vector-ref val 0))))
   ;; ((variant? val) (value-signature (variant-data val)))
   ((pair? val)
    (if (list? val)
        "unsupported" ;; todo
        (format "~a~a~a~a" (integer->char type-dict-entry-begin)
                (value-signature (car val))
                (value-signature (cdr val))
                (integer->char type-dict-entry-end))))))

(define (iter-append-basic-variant iter val)
  ;; (printf "iter-append-basic-variant ~s~%" val)
  (let ((signature (value-signature val)))
    ;; (printf "iter-append-basic-variant: sig ~s~%" signature)
    (let ((container ((foreign-lambda* message-iter-ptr ((message-iter-ptr iter) (c-string signature))
                        "DBusMessageIter* container = malloc(sizeof(DBusMessageIter));\n"
                        "dbus_message_iter_open_container(iter, DBUS_TYPE_VARIANT, signature, container);\n"
                        "C_return(container);\n")
                      iter signature)))
      (iter-append-basic container val)
      ((foreign-lambda* bool ((message-iter-ptr iter) (message-iter-ptr container))
         "bool ret = dbus_message_iter_close_container(iter, container);\n"
         "free(container);\n"
         "C_return(ret);\n")
       iter container))))

(define (iter-append-basic-struct iter val)
  ;; (printf "iter-append-basic-struct ~s~%" val)
  (let ((container ((foreign-lambda* message-iter-ptr ((message-iter-ptr iter))
                      "DBusMessageIter* container = malloc(sizeof(DBusMessageIter));\n"
                      "dbus_message_iter_open_container(iter, DBUS_TYPE_STRUCT, NULL, container);\n"
                      "C_return(container);\n")
                    iter)))
    (vector-for-each (lambda (i field) (iter-append-basic container field)) val)
    ((foreign-lambda* bool ((message-iter-ptr iter) (message-iter-ptr container))
       "bool ret = dbus_message_iter_close_container(iter, container);\n"
       "free(container);\n"
       "C_return (ret);\n")
     iter container)))

(define (iter-append-dict-entry iter pair)
  ;; (printf "iter-append-dict-entry ~s : ~s~%" (car pair) (cdr pair))
  (let ((signature (value-signature pair)))
    (let ((container ((foreign-lambda* message-iter-ptr ((message-iter-ptr iter) (c-string signature))
                        "DBusMessageIter* container = malloc(sizeof(DBusMessageIter));\n"
                        "dbus_message_iter_open_container(iter, DBUS_TYPE_DICT_ENTRY, NULL, container);\n"
                        "C_return(container);\n")
                      iter signature)))
      (iter-append-basic container (car pair))
      (iter-append-basic container (cdr pair))
      ((foreign-lambda* bool ((message-iter-ptr iter) (message-iter-ptr container))
         "bool ret = dbus_message_iter_close_container(iter, container);\n"
         "free(container);\n"
         "C_return(ret);\n")
       iter container))))

;; The first element of the vector determines the signature, so all
;; elements must have the same signature.
(define (iter-append-uniform-array iter vec)
  ;; (printf "iter-append-uniform-array ~s~%" vec)
  (if (> (vector-length vec) 0)
      ;; (let ((signature (format "~a~a" (ascii->string type-array) (value-signature (vector-ref vec 0)))))
      (let ((signature (value-signature (vector-ref vec 0))))
        ;; (printf "value signature ~s~%" signature)
        (let ((container ((foreign-lambda* message-iter-ptr ((message-iter-ptr iter) (c-string signature))
                            "DBusMessageIter* container = malloc(sizeof(DBusMessageIter));\n"
                            "dbus_message_iter_open_container(iter, DBUS_TYPE_ARRAY, signature, container);\n"
                            "C_return(container);\n")
                          iter signature)))
          (vector-for-each (lambda (i val)
                             ;; (printf "iter-append array element ~s ~s~%" i val)
                             (iter-append-basic container val)) vec)
          ((foreign-lambda* bool ((message-iter-ptr iter) (message-iter-ptr container))
             "bool ret = dbus_message_iter_close_container(iter, container);\n"
             "free(container);\n"
             "C_return(ret);\n")
           iter container)))
      ;; else todo: append empty array
      ))

;; TODO: iter-append-basic-object-path

;; val would usually be a single value, but
;; could be a pair of the form (type-x . value)
;; in which case we will attempt to convert the value to that type for sending.
(define (iter-append-basic iter val)
  ;; (printf "iter-append-basic ~s ~s~%" iter val)
  (cond
   ((fixnum? val) (iter-append-basic-int iter val))
   ((flonum? val) (iter-append-basic-double iter val))
   ((boolean? val) (iter-append-basic-bool iter val))
   ((variant? val) (iter-append-basic-variant iter (variant-data val)))
   ((struct? val) (iter-append-basic-struct iter (struct->vector val)))
   ((vector? val) (iter-append-uniform-array iter val))
   ((and (pair? val) (not (list? val))) (iter-append-dict-entry iter val))
   ((object-path? val) (iter-append-basic-object-path iter (object-path->string val)))
   (else (iter-append-basic-string iter (any->string val)))))

(define free-iter (foreign-lambda* void ((message-iter-ptr i)) "free(i);"))

(define (iter-cond iter)
  (let ((type ((foreign-lambda int "dbus_message_iter_get_arg_type"
                 message-iter-ptr) iter)))
    ;; (printf "iter-cond type ~s~%" type)
    (cond
     ((eq? type type-string)
      ((foreign-lambda* c-string ((message-iter-ptr iter))
         "char* ret = NULL;\n"
         "dbus_message_iter_get_basic(iter, &ret);\n"
         "C_return (ret);\n")
       iter))
     ((eq? type type-object-path)
      (let ((str ((foreign-lambda* c-string ((message-iter-ptr iter))
                    "char* ret = NULL;\n"
                    "dbus_message_iter_get_basic(iter, &ret);\n"
                    "C_return (ret);\n")
                  iter)))
        (if (auto-unbox-object-paths)
            str
            (string->object-path str))))
     ((eq? type type-boolean)
      ((foreign-lambda* bool ((message-iter-ptr iter))
         "bool ret;\n"
         "dbus_message_iter_get_basic(iter, &ret);\n"
         "return (ret);\n") iter))
     ((memq type `(,type-int32 ,type-byte
                               ,type-int16 ))
      ((foreign-lambda* int ((message-iter-ptr iter))
         "int ret = 0;\n"
         "dbus_message_iter_get_basic(iter, &ret);\n"
         "C_return (ret);\n")
       iter))
     ((memq type `(,type-uint32 ,type-uint16))
      ((foreign-lambda* unsigned-int ((message-iter-ptr iter))
         "unsigned int ret = 0;\n"
         "dbus_message_iter_get_basic(iter, &ret);\n"
         "C_return (ret);\n")
       iter))
     ((memq type `(,type-flonum ,type-uint64))
      ;; todo don't put 64-bit int into a flonum if there's another way
      ((foreign-lambda* double ((message-iter-ptr iter))
         "double ret;\n"
         "dbus_message_iter_get_basic(iter, &ret);\n"
         "C_return (ret);\n")
       iter))
     ((eq? type type-int64)
      ((foreign-lambda* integer64 ((message-iter-ptr iter))
         "int64_t ret = 0;\n"
         "dbus_message_iter_get_basic(iter, &ret);\n"
         "C_return (ret);\n")
       iter))
     ((eq? type type-array)
      (let ((v  (iter->vector (make-sub-iter iter))))
        (when (and (vector? v) (eq? 1 (vector-length v)) (unsupported-type? (vector-ref v 0)))
          (set! v (make-vector 0)))
        v))
     ((eq? type type-dict-entry)
      (iter->pair (make-sub-iter iter)))
     ((eq? type type-struct)
      (let ((v (iter->vector (make-sub-iter iter))))
        (if (auto-unbox-structs) v (vector->struct v))))
     ((eq? type type-variant)
      (if (auto-unbox-variants)
          ((make-sub-iter iter))
          (make-variant ((make-sub-iter iter)))))

     ;; todo: unsupported so far (not understood well enough):
     ;;       type-object-path and type-signature

     ;; so far the DBus "invalid" type is treated the same as unsupported.
     ;; Maybe need a distinction though...

     ;; ((eq? type type-invalid) ...)
     (else (make-unsupported-type (integer->char type))))))

(define (make-sub-iter iter)
  (let* ((sub ((foreign-lambda* message-iter-ptr ((message-iter-ptr iter))
                 "DBusMessageIter* i = malloc(sizeof(DBusMessageIter));\n"
                 "dbus_message_iter_recurse(iter, i);\n"
                 "C_return (i);\n")
               iter))
         (has-next sub))
    (lambda ()
      (if has-next
          (let ((ret (iter-cond sub)))
            (set! has-next ((foreign-lambda bool
                                "dbus_message_iter_next" message-iter-ptr) sub))
            ret)
          (begin
            (free-iter sub)
            iterm)))))

;; iterator for reading parameters from a message
;; returns a lambda which provides one param at a time, terminating with (void)
(define (make-iter msg)
  (let* ((iter ((foreign-lambda* message-iter-ptr ((message-ptr msg))
                  "DBusMessageIter* i = malloc(sizeof(DBusMessageIter));\n"
                  "if (!dbus_message_iter_init (msg, i))\n"
                  "    i = (DBusMessageIter*)0; // Message has no parameters\n"
                  "C_return (i);\n") msg))
         (has-next iter))
    (lambda ()
      (if has-next
          (let ((ret (iter-cond iter)))
            (set! has-next ((foreign-lambda bool
                                "dbus_message_iter_next" message-iter-ptr) iter))
            ret)
          (begin
            (free-iter iter)
            iterm)))))

;; todo maybe: rewrite to avoid the reverse
(define (iter->list iter)
  (let loop ((retval '()))
    (let ((next (iter)))
      (if (eq? next iterm)
          (reverse retval)
          (loop (cons next retval))))))

(define (iter->pair iter)
  (cons (iter) (iter)))

(define (iter->vector iter)
  (let ((l (iter->list iter)))
    (list->vector l)))

(define (find-callback bus msg)
  (let ((path (string?->symbol (msg-path msg)))
        (iface (string?->symbol (msg-interface msg)))
        (mber (string?->symbol (msg-member msg)))
        (svc (string?->symbol (msg-service msg))))
    ;; (printf "   svc ~s~%" svc)
    ;; (printf "   path ~s~%" path)
    ;; (printf "   iface ~s~%" iface)
    ;; (printf "   mber ~s~%" mber)
    ;;
    ;; The service name is not included as part of the signal, so svc will be #f.
    ;; In that case the callback is registered under bus/path/iface/signal-name.
    (let ((ret (and svc (tassq callbacks-table bus path svc iface mber))))
      (unless ret
        (set! ret (tassq callbacks-table bus path iface mber)))
      (unless ret
        (when (default-signal-handler)
          ((default-signal-handler)
           (make-context bus: bus path: path path service: svc interface: iface)
           mber #f))) ;; TODO get payload (args)
      ret)))

(define (make-context #!key (bus session-bus) service interface (path "/"))
  (vector (next-context-ID) bus (string?->symbol service)
          (string?->symbol path) (string?->symbol interface)))

(define send-impl
  (foreign-lambda int "dbus_connection_send" connection-ptr message-ptr uint-ptr))

(define (send context name . params)
  (let* ((service (symbol?->string (vector-ref context context-idx-service)))
         (msg (make-signal
               (symbol?->string (vector-ref context context-idx-path))
               (symbol?->string (vector-ref context context-idx-interface))
               name))
         (iter (make-iter-append msg)))
    (let ((conn (conn-or-abort (vector-ref context context-idx-bus))))
      ;; (exists-or-abort conn (format "no connection to bus ~s~%" (vector-ref context context-idx-bus)))
      (for-each
       (lambda (parm) (iter-append-basic iter parm))
       params)
      (send-impl conn msg #f)
      (free-iter iter)
      ;; ((foreign-lambda void "dbus_connection_flush" connection-ptr) conn)
      )))

(define (call context name . params)
  (let* ((service (symbol?->string (vector-ref context context-idx-service)))
         (msg (make-message service
                            (symbol->string (vector-ref context context-idx-path))
                            (symbol->string (vector-ref context context-idx-interface))
                            name))
         (iter (make-iter-append msg)))
    (let ((conn (conn-or-abort (vector-ref context context-idx-bus))))
      ;; (exists-or-abort conn (format "no connection to bus ~s~%" (vector-ref context context-idx-bus)))
      (for-each
       (lambda (parm) (iter-append-basic iter parm))
       params)
      (free-iter iter)
      (let* ((err (make-error))
             (reply-msg ((foreign-lambda* message-ptr ((connection-ptr conn) (message-ptr msg)
                                                       ((c-pointer (struct "DBusError")) err))
                           ;; todo: timeout comes from where?  (make-parameter) maybe
                           "DBusMessage *reply;\n"
                           "reply = dbus_connection_send_with_reply_and_block(conn, msg, 5000, err);\n"
                           "C_return(reply);\n")
                         conn msg err)))
        (if reply-msg
            (let* ((reply-iter (make-iter reply-msg))
                   (reply-args (iter->list reply-iter)))
              reply-args)
            (raise-dbus-error 'call err))))))

(define (make-method-proxy context name)
  (let ((service (symbol->string (vector-ref context context-idx-service)))
        (conn (conn-or-abort (vector-ref context context-idx-bus))))
    ;; (exists-or-abort conn (format "no connection to bus ~s~%" (vector-ref context context-idx-bus)))
    (lambda params
      (let* ((msg (make-message service
                                (symbol->string (vector-ref context context-idx-path))
                                (symbol->string (vector-ref context context-idx-interface))
                                name))
             (iter (make-iter-append msg)))
        (for-each
         (lambda (parm) (iter-append-basic iter parm))
         params)
        (free-iter iter)
        ;; TODO: pull this out into a helper function
        (and-let* ((reply-msg ((foreign-lambda* message-ptr ((connection-ptr conn) (message-ptr msg))
                                 ;; idealistic code here; todo: error checking
                                 "DBusPendingCall* pending;\n"
                                 "dbus_connection_send_with_reply(conn, msg, &pending, -1);\n"
                                 "dbus_connection_flush(conn);\n"
                                 "dbus_pending_call_block(pending);\n"
                                 "msg = dbus_pending_call_steal_reply(pending);\n"
                                 "C_return(msg);\n")
                               conn msg))
                   (reply-iter (make-iter reply-msg))
                   (reply-args (iter->list reply-iter)))
          reply-args)))))

(define-foreign-record-type (vtable "struct DBusObjectPathVTable")
  (constructor: make-vtable-impl)
  (destructor: free-vtable)
  (c-pointer unregister_function vtable-unregister_function vtable-unregister_function-set!)
  (c-pointer message_function vtable-message_function vtable-message_function-set!)
  (c-pointer dbus_internal_pad1 vtable-dbus_internal_pad1)
  (c-pointer dbus_internal_pad2 vtable-dbus_internal_pad2)
  (c-pointer dbus_internal_pad3 vtable-dbus_internal_pad3)
  (c-pointer dbus_internal_pad4 vtable-dbus_internal_pad4))

(define (make-vtable cb unreg-cb)
  (let ()
    (define (fn conn msg user-data)
      ;; (printf "fixin' to call ~a with ~a, ~a, ~a~%" cb conn msg user-data)
      (let ((ret (cb conn msg user-data)))
        ;; TODO: return ret as the result
        result-handled ))
    (let ((ret (make-vtable-impl)))
      (vtable-message_function-set! ret fn)
      (vtable-unregister_function-set! ret unreg-cb)
      ret)))

;; (set! add-match-self (lambda ()
;; ((foreign-safe-lambda void "dbus_bus_add_match" connection-ptr c-string error-ptr)
;; (get-conn (vector-ref context context-idx-bus)) rule #f)))

(define (read-write conn timeout)
  ((foreign-safe-lambda bool "dbus_connection_read_write" connection-ptr int)
   conn timeout))

(define (request-name context)
  (let ((service-name (symbol?->string (vector-ref context context-idx-service))))
    (conn-or-abort (vector-ref context context-idx-bus))
    (when service-name
      ((foreign-safe-lambda void "dbus_bus_request_name" connection-ptr c-string int error-ptr)
       (get-conn (vector-ref context context-idx-bus))
       service-name
       name-flag-replace-existing #f))))

(define (add-match context)
  ;; TODO is it always type signal?  We are using this for methods too.
  (let ((rule (format "type='signal', interface='~s'" (vector-ref context context-idx-interface))))
    (conn-or-abort (vector-ref context context-idx-bus))
    ((foreign-safe-lambda void "dbus_bus_add_match" connection-ptr c-string error-ptr)
     (get-conn (vector-ref context context-idx-bus)) rule #f)))

;; return #t if it received a message, #f if not
(define (poll-for-message #!key (bus session-bus) (timeout 0))
  (let ((conn (conn-or-abort bus)))
    ;; (exists-or-abort conn (format "no connection to bus ~s~%" (vector-ref context context-idx-bus)))
    ((foreign-safe-lambda* bool
         ((connection-ptr conn) (bus bus) (int timeout))
       "DBusMessage* msg = NULL;\n"
       "dbus_connection_read_write(conn, timeout);\n"
       "msg = dbus_connection_pop_message(conn);\n"
       "if (msg) {\n"
       "    //printf(\"rcv: %s\\n\", dbus_message_get_interface(msg));\n"
       "    C_msg_cb(bus, msg);\n"
       "    C_return(true); // yes there was a message\n"
       "}\n"
       "C_return (false); // we polled, we came back empty-handed\n")
     conn bus timeout)))

;; TODO: one polling thread is necessary for each connection
(define (start-polling! bus interval)
  (vector-set! polling-interval bus interval)
  ;; (pretty-print callbacks-table)
  (when (vector-ref polling-enabled bus)
    (unless (vector-ref polling-threads bus)
      (vector-set! polling-threads bus
                   (thread-start!
                    (lambda ()
                      (let loop ()
                        ;; (printf "polling~%")
                        (poll-for-message bus: bus timeout: 0)
                        (thread-sleep! (vector-ref polling-interval bus))
                        (when (vector-ref polling-enabled bus) (loop)))))))))

(define (enable-polling-thread! #!key (bus session-bus) (enable #t)
                                (interval default-polling-interval))
  (vector-set! polling-enabled bus enable)
  (if enable
      (start-polling! bus interval)
      (let ((th (vector-ref polling-threads bus)))
        (when th (thread-join! th)))))

;; Wraps a user-provided callback so as to pass it the
;; received dbus message's parameters, and return a dbus response
;; with the parameter(s) returned from the callback.
;; msg-cb is the user-provided one.
(define (method-wrapper conn msg-cb)
  (lambda (msg)
    (let ((args (iter->list (make-iter msg)))
          (response ((foreign-lambda message-ptr
                         "dbus_message_new_method_return" message-ptr) msg)))
      (let ((ret (apply msg-cb args))
            (iter (make-iter-append response)))
        (if (pair? ret)
            (for-each (lambda (parm)
                        ;; (printf "appending return parameter ~s~%" parm)
                        (iter-append-basic iter parm))
                      ret)
            (iter-append-basic iter ret))
        ;; send response
        (send-impl conn response #f)
        (free-iter iter)))))

(define (handler-wrapper conn msg-cb)
  (lambda (msg)
    (let ((args (iter->list (make-iter msg))))
      (apply msg-cb args))))

;; msg-cb: the handler implementation.  Its return value is ignored.
(define (register-signal-handler context name msg-cb)
  (request-name context)
  (add-match context)
  (tasset! callbacks-table
           (handler-wrapper (conn-or-abort (vector-ref context context-idx-bus)) msg-cb)
           (vector-ref context context-idx-bus)
           (vector-ref context context-idx-path)
           (vector-ref context context-idx-interface)
           (string?->symbol name))
  (start-polling! (vector-ref context context-idx-bus) default-polling-interval))

;; msg-cb: the method implementation.  Its return value is sent back as the response.
(define (register-method context name msg-cb)
  (request-name context)
  ;; (add-match context) doesn't seem to be necessary
  (tasset! callbacks-table
           (method-wrapper (conn-or-abort (vector-ref context context-idx-bus)) msg-cb)
           (vector-ref context context-idx-bus)
           (vector-ref context context-idx-path)
           (vector-ref context context-idx-service)
           (vector-ref context context-idx-interface)
           (string?->symbol name))
  (start-polling! (vector-ref context context-idx-bus) default-polling-interval))

;; dbus_bool_t dbus_connection_register_object_path
;; (DBusConnection              *connection,
;;  const char                  *path,
;;  const DBusObjectPathVTable  *vtable,
;;  void                        *user_data);
(define (register-path bus path fn unreg-fn)
  ;; (let ((unreg-fn (lambda (parm . rest) #f)))
  ((foreign-safe-lambda bool "dbus_connection_register_object_path"
     connection-ptr c-string vtable-ptr c-pointer)
   (conn-or-abort bus)
   (symbol?->string path)
   (make-vtable fn unreg-fn)
   #f))

(define (discover-api-xml ctxt)
  (let ((ctxt (list->vector (vector->list ctxt)))) ;; todo: efficiency?
    (vector-set! ctxt context-idx-interface 'org.freedesktop.DBus.Introspectable)
    (let ((xml (call ctxt "Introspect")))
      (and (pair? xml) (car xml)))))

) ;; end module
