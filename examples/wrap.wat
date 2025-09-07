(module
  ;; Import memory from the main module
  (import "env" "memory" (memory 1))
  
  ;; Export random_get function that fills buffer with dummy value 1
  (func (export "random_get") (param $buf i32) (param $len i32) (result i32)
    (local $i i32)
    
    ;; Initialize loop counter
    (local.set $i (i32.const 0))
    
    ;; Loop to fill the buffer with value 1
    (block $done
      (loop $fill
        ;; Check if we've filled the requested length
        (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
        
        ;; Store the dummy value 1 at buf[i]
        (i32.store8
          (i32.add (local.get $buf) (local.get $i))
          (i32.const 1)
        )
        
        ;; Increment counter
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        
        ;; Continue loop
        (br $fill)
      )
    )
    
    ;; Return success (0)
    (i32.const 0)
  )
)