;;;; dbus.scm

(module dbus (dbus:make-context
	      dbus:send
	      dbus:call
	      dbus:make-method-proxy
	      dbus:register-signal-handler
	      dbus:register-method
	      dbus:enable-polling-thread!
	      dbus:poll-for-message
	      dbus:discover-services
	      dbus:discover-api-xml
	      dbus:dbus-service
	      dbus:type-uint32
	      dbus:session-bus
	      dbus:system-bus
	      dbus:starter-bus
	      dbus:known-bus-count
	      dbus:register-path)
	(import scheme chicken
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

; Would want to do this:
; (define-foreign-enum (dbus:bus (enum "DBusBusType"))
	; (dbus:session-bus DBUS_BUS_SESSION)
	; (dbus:system-bus DBUS_BUS_SYSTEM)
	; (dbus:starter-bus DBUS_BUS_STARTER) )
; but because that enum is typedef'd, chicken has a problem with it.

(define-foreign-type dbus:bus int) ; really "DBusBusType"
(define dbus:session-bus (foreign-value DBUS_BUS_SESSION int))
(define dbus:system-bus (foreign-value DBUS_BUS_SYSTEM int))
(define dbus:starter-bus (foreign-value DBUS_BUS_STARTER int))
(define dbus:dbus-service (foreign-value DBUS_SERVICE_DBUS c-string))
(define dbus:known-bus-count (+ 1 (max dbus:session-bus dbus:system-bus dbus:starter-bus)))

(define-foreign-type dbus:handler-result int) ; really "DBusHandlerResult"
(define dbus:result-handled (foreign-value DBUS_HANDLER_RESULT_HANDLED int))
(define dbus:result-not-yet-handled (foreign-value DBUS_HANDLER_RESULT_NOT_YET_HANDLED int))
(define dbus:result-need-memory (foreign-value DBUS_HANDLER_RESULT_NEED_MEMORY int))

(define dbus:name-flag-allow-replacement (foreign-value DBUS_NAME_FLAG_ALLOW_REPLACEMENT int))
(define dbus:name-flag-replace-existing (foreign-value DBUS_NAME_FLAG_REPLACE_EXISTING int))
(define dbus:name-flag-do-not-queue (foreign-value DBUS_NAME_FLAG_DO_NOT_QUEUE int))

;; DBus simple data types
(define dbus:type-invalid (foreign-value DBUS_TYPE_INVALID int))
(define dbus:type-invalid-string (foreign-value DBUS_TYPE_INVALID_AS_STRING int))
(define dbus:type-byte  (foreign-value DBUS_TYPE_BYTE int))
(define dbus:type-byte-string  (foreign-value DBUS_TYPE_BYTE_AS_STRING int))
(define dbus:type-boolean  (foreign-value DBUS_TYPE_BOOLEAN int))
(define dbus:type-boolean-string  (foreign-value DBUS_TYPE_BOOLEAN_AS_STRING int))
(define dbus:type-int16  (foreign-value DBUS_TYPE_INT16 int))
(define dbus:type-int16-string  (foreign-value DBUS_TYPE_INT16_AS_STRING int))
(define dbus:type-uint16  (foreign-value DBUS_TYPE_UINT16 int))
(define dbus:type-uint16-string  (foreign-value DBUS_TYPE_UINT16_AS_STRING int))
(define dbus:type-fixnum (foreign-value DBUS_TYPE_INT32 int))
(define dbus:type-int32  (foreign-value DBUS_TYPE_INT32 int))
(define dbus:type-int32-string  (foreign-value DBUS_TYPE_INT32_AS_STRING int))
(define dbus:type-uint32  (foreign-value DBUS_TYPE_UINT32 int))
(define dbus:type-uint32-string  (foreign-value DBUS_TYPE_UINT32_AS_STRING int))
(define dbus:type-int64  (foreign-value DBUS_TYPE_INT64 int))
(define dbus:type-int64-string  (foreign-value DBUS_TYPE_INT64_AS_STRING int))
(define dbus:type-uint64  (foreign-value DBUS_TYPE_UINT64 int))
(define dbus:type-uint64-string  (foreign-value DBUS_TYPE_UINT64_AS_STRING int))
(define dbus:type-double  (foreign-value DBUS_TYPE_DOUBLE int))
(define dbus:type-flonum  (foreign-value DBUS_TYPE_DOUBLE int))
(define dbus:type-double-string  (foreign-value DBUS_TYPE_DOUBLE_AS_STRING int))
(define dbus:type-string  (foreign-value DBUS_TYPE_STRING int))
(define dbus:type-string-string  (foreign-value DBUS_TYPE_STRING_AS_STRING int))
(define dbus:type-object-path  (foreign-value DBUS_TYPE_OBJECT_PATH int))
(define dbus:type-signature  (foreign-value DBUS_TYPE_SIGNATURE int))
(define dbus:type-signature-string  (foreign-value DBUS_TYPE_SIGNATURE_AS_STRING int))
(define dbus:type-array (foreign-value DBUS_TYPE_ARRAY int))
(define dbus:type-array-string  (foreign-value DBUS_TYPE_ARRAY_AS_STRING int))
(define dbus:type-dict  (foreign-value DBUS_TYPE_DICT_ENTRY int))
(define dbus:type-variant (foreign-value DBUS_TYPE_VARIANT int))

(define dbus:make-context)
(define dbus:send)
(define dbus:make-method-proxy)
(define dbus:call)
(define dbus:flush)
(define dbus:poll-for-message)
(define dbus:register-signal-handler)
(define dbus:register-method)
(define dbus:register-path)
(define dbus:enable-polling-thread!)

(define dbus:add-match)
(define dbus:request-name)


(define find-callback)

(define-foreign-type error-ptr c-pointer) ;; DBusError*
(define-foreign-type connection-ptr c-pointer)	;; DBusConnection*
(define-foreign-type message-ptr c-pointer)	;; DBusMessage*
(define-foreign-type uint-ptr c-pointer)	;; dbus_uint32_t*
(define-foreign-type message-iter-ptr c-pointer)  	;; DBusMessageIter*
(define-foreign-type vtable-ptr c-pointer)  	;; DBusObjectPathVTable*

(define (dbus:discover-services #!key (bus dbus:session-bus))
	(let* ([ctxt (dbus:make-context
					bus: bus
					service: 'org.freedesktop.DBus
					interface: 'org.freedesktop.DBus
					path: '/org/freedesktop/DBus)]
			[services (dbus:call ctxt "ListNames")])
		(and (pair? services) (vector? (car services)) (vector->list (car services)))))

(define dbus:discover-api-xml)

(define-external (C_msg_cb (dbus:bus bus) (message-ptr msg)) bool
	(let* ([cb (find-callback bus msg)][found (procedure? cb)])
		; (printf "got a message: ~s on bus ~a and found callback ~s~%" msg bus cb)
		(when found
			(cb msg))
		found
	))

(let (	[connections '()]	;; an alist mapping dbus:bus to DBusConnection ptrs
		[error (foreign-value "&err" c-pointer)]
		;; indices in a "context" vector
		[context-idx-ID 0]
		[context-idx-bus 1]
		[context-idx-service 2]
		[context-idx-path 3]
		[context-idx-interface 4]
		[context-count 0]
		[default-polling-interval 0.01]
		[polling-interval (make-vector dbus:known-bus-count 0.01)]
		[polling-enabled (make-vector dbus:known-bus-count #t)]
		[polling-threads (make-vector dbus:known-bus-count #f)]
		;; will become an assoc tree:
		;; bus
		;;   path
		;;     service (unless it's a signal callback)
		;;       interface
		;;         method
		;;           callback-fn
		[callbacks-table `((,dbus:system-bus . #f) (,dbus:session-bus . #f))]
		[iterm (gensym 'terminiter)] )

    (define (any->string arg)
      (if (string? arg)
	arg
	(if (eq? (void) arg)
	  ""
	  (format "~a" arg)
	)))

	(define (symbol?->string arg)
		(if (symbol? arg)
			(symbol->string arg)
			arg))

	(define (string?->symbol arg)
		(if (string? arg)
			(string->symbol arg)
			arg))

	;; If the assq-list has the given key, replace its value.
	;; Else add the key-value pair.
	(define (asset! alist key val)
		(let ([pr (assq key alist)])
			(if pr
				(set-cdr! pr val)
				(if (null? (cdar alist))
					(set-car! alist (cons key val))
					(begin
						(set-cdr! alist (cons (car alist) (cdr alist)))
						(set-car! alist (cons key val))) ))))

	;; The "tree" version of assq: drills down into an assq-tree
	;; as directed by the sequence of keys, and returns the value found.
	;; #f means not found (so it is not useful to store #f in such a tree).
	(define (tassq tree . keys)
		(let ([key-list (if (pair? (car keys)) (car keys) keys)])
			(let loop ([rem-keys key-list][subtree tree])
				(if (null? rem-keys)
					subtree
					(loop (cdr rem-keys)
						(let ([pr (assq (car rem-keys) subtree)])
							(and (pair? pr) (cdr pr))))))))

	;; The "tree" version of asset!: drills down into an assq-tree
	;; as directed by the sequence of keys, making new branches as necessary,
	;; and sets the given value as a leaf at that point in the tree.
	;; return value is undefined
	(define (tasset! tree val . keys)
		(let ([key-list (if (pair? (car keys)) (car keys) keys)])
			(let loop (	[rem-keys (cdr key-list)]
						[subtree (tassq tree (car key-list))]
						[prev-key (car key-list)]
						[prev-subtree tree])
; (printf "rem-keys ~s subtree ~s prev-key ~s prev-subtree ~s~%" rem-keys subtree prev-key prev-subtree)
				(when (and (not subtree) (pair? rem-keys))
					(set! subtree (list (cons (car rem-keys) #f)))
; (printf "   creating subtree ~s within ~s~%" subtree prev-subtree)
					(asset! prev-subtree prev-key subtree)
; (pretty-print prev-subtree)
				)
				(if (null? rem-keys)
					(asset! prev-subtree prev-key val)
					(loop
						(cdr rem-keys)
						(let ([pr (assq (car rem-keys) subtree)])
							(unless (pair? pr)
								(set! pr (cons (car rem-keys) #f))
								(set-cdr! subtree (cons (car subtree) (cdr subtree)))
								(set-car! subtree pr) )
							(cdr pr))
						(car rem-keys)
						subtree	)))))

	(define (next-context-ID) (set! context-count (+ 1 context-count)) context-count)

	(define (get-conn bus-type)
		(let ([conn (assq bus-type connections)])
			(if (pair? conn)
				(set! conn (cdr conn))
				(begin
					(set! conn ((foreign-lambda connection-ptr "dbus_bus_get" dbus:bus error-ptr)
						bus-type error) )
					(when conn
						(set! connections (cons (cons bus-type conn) connections)))))
			conn))

	(define (conn-or-abort bus-type)
		(or (get-conn bus-type)
			(abort (format "unable to connect to bus ~s~%" bus-type))))

	(define (exists-or-abort datum err-str)
		(or datum
			(abort err-str)))

	;; params: path interface name
	;; todo: garbage-collect this
	(define make-signal (foreign-lambda message-ptr "dbus_message_new_signal"
		c-string c-string c-string))

	;; params: service path interface method-name
	;; todo: garbage-collect this
	(define make-message (foreign-lambda message-ptr "dbus_message_new_method_call"
		c-string c-string c-string c-string))

	;; todo: garbage-collect this
	(define make-iter-append
		(foreign-lambda* message-iter-ptr ((message-ptr msg))
			"DBusMessageIter* iter = malloc(sizeof(DBusMessageIter));
			dbus_message_iter_init_append (msg, iter);
			C_return (iter);"))

	(define iter-append-basic-string
		(foreign-lambda* bool ((message-iter-ptr iter) (c-string v))
			"C_return (dbus_message_iter_append_basic(iter, DBUS_TYPE_STRING, &v));"))

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

	;; TODO: iter-append-basic-T for each possible type:
	;; especially variant, array and struct might still be possible

	;; val would usually be a single value, but
	;; could be a pair of the form (dbus:type-x . value)
	;; in which case we will attempt to convert the value to that type for sending.
	(define (iter-append-basic iter val)
		(cond
			[(fixnum? val) (iter-append-basic-int iter val)]
			[(flonum? val) (iter-append-basic-double iter val)]
			[(boolean? val) (iter-append-basic-bool iter val)]
			[(pair? val)
				(let ([type (car val)])
					(cond
						;; TODO: this doesn't compile
						;; Error: Arguments to inlined call of `iter-append-basic-byte'
						;; do not match parameter-list (a207 a206)
						;; so I guess it has to _be_ a byte before the call
						; [(eq? type dbus:type-byte)
							; (iter-append-basic-byte (cdr val))]
						; [(eq? type dbus:type-int16)
							; (iter-append-basic-int16 (cdr val))]
						; [(eq? type dbus:type-uint32)
							; (iter-append-basic-uint32 (cdr val))]
						; [(eq? type dbus:type-uint16)
							; (iter-append-basic-uint16 (cdr val))]
						; [(eq? type dbus:type-int64)
							; (iter-append-basic-int64 (cdr val))]
						; [(eq? type dbus:type-uint64)
							; (iter-append-basic-uint64 (cdr val))]
						;; other custom requests will be handled as usual, above
						[else (iter-append-basic iter (cdr val))] ))]
			[else (iter-append-basic-string iter (any->string val))] ))

	(define free-iter (foreign-lambda* void ((message-iter-ptr i)) "free(i);"))

	(define (iter-cond iter)
		(let (	[type ((foreign-lambda int "dbus_message_iter_get_arg_type"
						message-iter-ptr) iter)] )
			(cond
				[(memq type `(,dbus:type-string ,dbus:type-invalid-string
								,dbus:type-string-string ,dbus:type-object-path
								,dbus:type-signature-string
								;; TODO maybe the following types ought to be converted?
								,dbus:type-byte-string ,dbus:type-boolean-string
								,dbus:type-int16-string ,dbus:type-uint16-string
								,dbus:type-int32-string ,dbus:type-uint32-string
								,dbus:type-int64-string ,dbus:type-uint64-string
								,dbus:type-double-string ))
					((foreign-lambda* c-string ((message-iter-ptr iter))
						"char* ret;
						dbus_message_iter_get_basic(iter, &ret);
						C_return (ret);") iter)]
				[(eq? type dbus:type-boolean)
					((foreign-lambda* bool ((message-iter-ptr iter))
						"bool ret;
						dbus_message_iter_get_basic(iter, &ret);
						return (ret);") iter)]
				[(memq type `(,dbus:type-int32 ,dbus:type-byte
								,dbus:type-int16 ))
					((foreign-lambda* int ((message-iter-ptr iter))
						"int ret;
						dbus_message_iter_get_basic(iter, &ret);
						C_return (ret);") iter)]
				[(memq type `(,dbus:type-uint32 ,dbus:type-uint16))
					((foreign-lambda* unsigned-int ((message-iter-ptr iter))
						"unsigned int ret;
						dbus_message_iter_get_basic(iter, &ret);
						C_return (ret);") iter)]
				[(memq type `(,dbus:type-flonum ,dbus:type-uint64))
					((foreign-lambda* double ((message-iter-ptr iter))
						"double ret;
						dbus_message_iter_get_basic(iter, &ret);
						C_return (ret);") iter)]
				[(eq? type dbus:type-int64)
					((foreign-lambda* integer64 ((message-iter-ptr iter))
						"int64_t ret;
						dbus_message_iter_get_basic(iter, &ret);
						C_return (ret);") iter)]
				[(eq? type dbus:type-array)
					(iter->vector (make-sub-iter iter))]
				[(eq? type dbus:type-dict)
					(iter->pair (make-sub-iter iter))]
				[(eq? type dbus:type-variant)
					((make-sub-iter iter))]
				;; unsupported so far (not understood well enough):
				;; 	dbus:type-object-path and dbus:type-signature
				;; dbus:type-invalid is returned as #f (could be (void) but that
				;; would be the termination condition for the iterator)
				;[else (format "unsupported-~c" (integer->char type))] )))
				[else #f] )))

	(define (make-sub-iter iter)
		(let* ([sub ((foreign-lambda* message-iter-ptr ((message-iter-ptr iter))
				"DBusMessageIter* i = malloc(sizeof(DBusMessageIter));
				dbus_message_iter_recurse(iter, i);
				C_return (i);") iter) ]
				[has-next sub]
				)
			(lambda ()
				(if has-next
					(let ([ret (iter-cond sub)])
						(set! has-next ((foreign-lambda bool
							"dbus_message_iter_next" message-iter-ptr) sub))
						ret	)
					(begin
						(free-iter sub)
						iterm)
				))))

	;; iterator for reading parameters from a message
	;; returns a lambda which provides one param at a time, terminating with (void)
	(define (make-iter msg)
		(let* ([iter ((foreign-lambda* message-iter-ptr ((message-ptr msg))
				"DBusMessageIter* i = malloc(sizeof(DBusMessageIter));
				if (!dbus_message_iter_init (msg, i))
					i = (DBusMessageIter*)0;	// Message has no parameters
				C_return (i);") msg) ]
				[has-next iter]
				)
			(lambda ()
				(if has-next
					(let ([ret (iter-cond iter)])
						(set! has-next ((foreign-lambda bool
							"dbus_message_iter_next" message-iter-ptr) iter))
						ret	)
					(begin
						(free-iter iter)
						iterm)
				))))

	;; todo maybe: rewrite to avoid the reverse
	(define (iter->list iter)
		(let loop ([retval '()])
			(let ([next (iter)])
				(if (eq? next iterm)
					(reverse retval)
					(loop (cons next retval))))))

	(define (iter->pair iter)
		(cons (iter) (iter)))

	(define (iter->vector iter)
		(let ([l (iter->list iter)])
			(list->vector l)))

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

	(set! find-callback (lambda (bus msg)
		(let ([path (string?->symbol (msg-path msg))]
				[iface (string?->symbol (msg-interface msg))]
				[mber (string?->symbol (msg-member msg))]
				[svc (string?->symbol (msg-service msg))]
				)
			; (printf "   svc ~s~%" svc)
			; (printf "   path ~s~%" path)
			; (printf "   iface ~s~%" iface)
			; (printf "   mber ~s~%" mber)
			;; The service name is not included as part of the signal, so svc will be #f.
			;; In that case the callback is registered under bus/path/iface/signal-name.
			(if svc
				(tassq callbacks-table bus path svc iface mber)
				(tassq callbacks-table bus path iface mber) ))))

	(set! dbus:make-context (lambda (#!key (bus dbus:session-bus) service interface (path "/"))
		(vector (next-context-ID) bus (string?->symbol service)
			(string?->symbol path) (string?->symbol interface)) ))

	(define send-impl
		(foreign-lambda int "dbus_connection_send" connection-ptr message-ptr uint-ptr))

	(set! dbus:send (lambda (context name . params)
		(let* (	[service (symbol?->string (vector-ref context context-idx-service))]
				[msg (make-signal
							(symbol?->string (vector-ref context context-idx-path))
							(symbol?->string (vector-ref context context-idx-interface))
							name)]
				[iter (make-iter-append msg)] )
			(let ([conn (conn-or-abort (vector-ref context context-idx-bus))])
				; (exists-or-abort conn (format "no connection to bus ~s~%" (vector-ref context context-idx-bus)))
				(for-each (lambda (parm)
					(iter-append-basic iter parm))	params)
				(send-impl conn msg #f)
				(free-iter iter)
				; ((foreign-lambda void "dbus_connection_flush" connection-ptr) conn)
			))))

	(set! dbus:call (lambda (context name . params)
		(let* (	[service (symbol->string (vector-ref context context-idx-service))]
				[msg (make-message service
							(symbol->string (vector-ref context context-idx-path))
							(symbol->string (vector-ref context context-idx-interface))
							name)]
				[iter (make-iter-append msg)] )
			(let ([conn (conn-or-abort (vector-ref context context-idx-bus))])
				; (exists-or-abort conn (format "no connection to bus ~s~%" (vector-ref context context-idx-bus)))
				(for-each (lambda (parm)
					(iter-append-basic iter parm))	params)
				(free-iter iter)
				(let* (	[reply-msg ((foreign-lambda* message-ptr ((connection-ptr conn) (message-ptr msg))
							;; idealistic code here; todo: error checking
							;; todo: timeout comes from where?  (make-parameter) maybe
							"DBusMessage *reply;
							DBusError error;
							dbus_error_init (&error);
							reply = dbus_connection_send_with_reply_and_block(conn, msg, 5000, &error);
							if (dbus_error_is_set (&error))
								fprintf (stderr, \"Error %s: %s\\n\", error.name, error.message);
							dbus_message_unref(msg);
							C_return(reply);") conn msg) ]
						[reply-iter (make-iter reply-msg)]
						[reply-args (iter->list reply-iter)] )
					reply-args)))))

	(set! dbus:make-method-proxy (lambda (context name)
		(let (	[service (symbol->string (vector-ref context context-idx-service))]
				[conn (conn-or-abort (vector-ref context context-idx-bus))] )
				; (exists-or-abort conn (format "no connection to bus ~s~%" (vector-ref context context-idx-bus)))
				(lambda params
					(let* (	[msg (make-message service
									(symbol->string (vector-ref context context-idx-path))
									(symbol->string (vector-ref context context-idx-interface))
									name)]
							[iter (make-iter-append msg)] )
						(for-each (lambda (parm)
							(iter-append-basic iter parm))	params)
						(free-iter iter)
						;; TODO: pull this out into a helper function
						(let* (	[reply-msg ((foreign-lambda* message-ptr ((connection-ptr conn) (message-ptr msg))
									;; idealistic code here; todo: error checking
									"DBusPendingCall* pending;
									dbus_connection_send_with_reply(conn, msg, &pending, -1);
									dbus_connection_flush(conn);
									dbus_message_unref(msg);
									dbus_pending_call_block(pending);
									msg = dbus_pending_call_steal_reply(pending);
									C_return(msg);") conn msg) ]
								[reply-iter (make-iter reply-msg)]
								[reply-args (iter->list reply-iter)] )
							reply-args))))))

	(define-foreign-record-type (dbus:vtable "struct DBusObjectPathVTable")
		(constructor: dbus:make-vtable-impl)
		(destructor: dbus:free-vtable)
		(c-pointer unregister_function dbus:vtable-unregister_function dbus:vtable-unregister_function-set!)
		(c-pointer message_function dbus:vtable-message_function dbus:vtable-message_function-set!)
		(c-pointer dbus_internal_pad1 dbus:vtable-dbus_internal_pad1)
		(c-pointer dbus_internal_pad2 dbus:vtable-dbus_internal_pad2)
		(c-pointer dbus_internal_pad3 dbus:vtable-dbus_internal_pad3)
		(c-pointer dbus_internal_pad4 dbus:vtable-dbus_internal_pad4))

	(define (dbus:make-vtable cb unreg-cb)
		(let ()
			(define (fn conn msg user-data)
				; (printf "fixin' to call ~a with ~a, ~a, ~a~%" cb conn msg user-data)
				(let ([ret (cb conn msg user-data)])
					;; TODO: return ret as the result
					dbus:result-handled ))
			(let ([ret (dbus:make-vtable-impl)])
				(dbus:vtable-message_function-set! ret fn)
				(dbus:vtable-unregister_function-set! ret unreg-cb)
				ret) ))

	; (set! dbus:add-match-self (lambda ()
		; ((foreign-safe-lambda void "dbus_bus_add_match" connection-ptr c-string error-ptr)
			; (get-conn (vector-ref context context-idx-bus)) rule #f) ))

	(set! dbus:read-write (lambda (conn timeout)
		(let ()
			((foreign-safe-lambda bool "dbus_connection_read_write" connection-ptr int)
				conn timeout))))

	(set! dbus:request-name (lambda (context)
		(let ([service-name (symbol?->string (vector-ref context context-idx-service))])
			(conn-or-abort (vector-ref context context-idx-bus))
			(when service-name
				((foreign-safe-lambda void "dbus_bus_request_name" connection-ptr c-string int error-ptr)
					(get-conn (vector-ref context context-idx-bus))
					service-name
					dbus:name-flag-replace-existing #f) ))))

	(set! dbus:add-match (lambda (context)
		;; TODO is it always type signal?  We are using this for methods too.
		(let ([rule (format "type='signal', interface='~s'" (vector-ref context context-idx-interface))])
			(conn-or-abort (vector-ref context context-idx-bus))
			((foreign-safe-lambda void "dbus_bus_add_match" connection-ptr c-string error-ptr)
				(get-conn (vector-ref context context-idx-bus)) rule #f) )))

	;; return #t if it received a message, #f if not
	(set! dbus:poll-for-message (lambda (#!key (bus dbus:session-bus) (timeout 0))
		(let ([conn (conn-or-abort bus)])
			; (exists-or-abort conn (format "no connection to bus ~s~%" (vector-ref context context-idx-bus)))
			((foreign-safe-lambda* bool
				((connection-ptr conn) (dbus:bus bus) (int timeout))
				"DBusMessage* msg = NULL;
				dbus_connection_read_write(conn, timeout);
				msg = dbus_connection_pop_message(conn);
				if (msg)
				{
					//printf(\"rcv: %s\\n\", dbus_message_get_interface(msg));
					C_msg_cb(bus, msg);
					dbus_message_unref(msg);
					C_return(true);		// yes there was a message
				}
				C_return (false);		// we polled, we came back empty-handed
				") conn bus timeout)
		)))

	;; TODO: one polling thread is necessary for each connection
	(define (dbus:start-polling! bus interval)
		(vector-set! polling-interval bus interval)
		; (pretty-print callbacks-table)
		(when (vector-ref polling-enabled bus)
			(unless (vector-ref polling-threads bus)
				(vector-set! polling-threads bus (thread-start! (lambda ()
					(let loop ()
						; (printf "polling~%")
						(dbus:poll-for-message bus: bus timeout: 0)
						(thread-sleep! (vector-ref polling-interval bus))
						(when (vector-ref polling-enabled bus) (loop)))))))))

	(set! dbus:enable-polling-thread! (lambda (#!key (bus dbus:session-bus) (enable #t) (interval default-polling-interval))
		(vector-set! polling-enabled bus enable)
		(if enable
			(dbus:start-polling! bus interval)
			(let ([th (vector-ref polling-threads bus)])
				(when th (thread-join! th))))))

	;; Wraps a user-provided callback so as to pass it the
	;; received dbus message's parameters, and return a dbus response
	;; with the parameter(s) returned from the callback.
	;; msg-cb is the user-provided one.
	(define (method-wrapper conn msg-cb)
		(lambda (msg)
			(let (	[args (iter->list (make-iter msg))]
					[response ((foreign-lambda message-ptr
							"dbus_message_new_method_return" message-ptr) msg)])
				(let (	[ret (apply msg-cb args)]
						[iter (make-iter-append response)] )
					(if (pair? ret)
						(for-each (lambda (parm)
							; (printf "appending return parameter ~s~%" parm)
							(iter-append-basic iter parm))	ret)
						(iter-append-basic iter ret))
					;; send response
					(send-impl conn response #f)
					(free-iter iter)
					))))

	(define (handler-wrapper conn msg-cb)
		(lambda (msg)
			(let ([args (iter->list (make-iter msg))])
				(apply msg-cb args)	)))

	;; msg-cb: the handler implementation.  Its return value is ignored.
	(set! dbus:register-signal-handler (lambda (context name msg-cb)
		(dbus:request-name context)
		(dbus:add-match context)
		(tasset! callbacks-table
			(handler-wrapper (conn-or-abort (vector-ref context context-idx-bus)) msg-cb)
			(vector-ref context context-idx-bus)
			(vector-ref context context-idx-path)
			(vector-ref context context-idx-interface)
			(string?->symbol name))
		(dbus:start-polling! (vector-ref context context-idx-bus) default-polling-interval)
	))

	;; msg-cb: the method implementation.  Its return value is sent back as the response.
	(set! dbus:register-method (lambda (context name msg-cb)
		(dbus:request-name context)
		; (dbus:add-match context)	doesn't seem to be necessary
		(tasset! callbacks-table
			(method-wrapper (conn-or-abort (vector-ref context context-idx-bus)) msg-cb)
			(vector-ref context context-idx-bus)
			(vector-ref context context-idx-path)
			(vector-ref context context-idx-service)
			(vector-ref context context-idx-interface)
			(string?->symbol name))
		(dbus:start-polling! (vector-ref context context-idx-bus) default-polling-interval)
	))

	; dbus_bool_t dbus_connection_register_object_path   (DBusConnection              *connection,
														; const char                  *path,
														; const DBusObjectPathVTable  *vtable,
														; void                        *user_data);
	(set! dbus:register-path (lambda (bus path fn unreg-fn)
		; (let ([unreg-fn (lambda (parm . rest) #f)])
		((foreign-safe-lambda bool "dbus_connection_register_object_path"
				connection-ptr c-string vtable-ptr c-pointer)
			(conn-or-abort bus)
			(symbol?->string path)
			(dbus:make-vtable fn unreg-fn) #f)))

	(set! dbus:discover-api-xml (lambda (ctxt)
		(let ([ctxt (list->vector (vector->list ctxt))])	;; todo: efficiency?
			(vector-set! ctxt context-idx-interface 'org.freedesktop.DBus.Introspectable)
			(let ([xml (dbus:call ctxt "Introspect")])
				(and (pair? xml) (car xml))))))

)) ;; end module
