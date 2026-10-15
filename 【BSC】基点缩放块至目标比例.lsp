(vl-load-com)
(defun c:BSC (/ *error* DOC *Old_SysVar* SS i en ent)
  (setq DOC (vla-get-ActiveDOCument (vlax-get-acad-object)))
  (defun *error*(msg)
    (if *Old_SysVar* 
      (foreach xx *Old_SysVar* (apply 'setvar xx)) ;参数恢复
    )
    (vla-endundomark DOC)
  )
  (vla-startundomark Doc) ;记录编组
    (progn ;记录系统变量设置标注比例
      (setq *Old_SysVar* '());清空变量,避免出错
      (setq *Old_SysVar* 
          (mapcar 
            '(lambda (a / b) 
              (if (setq b (getvar (car a))) 
                (progn 
                  (apply 'setvar a)
                  (list (car a) b)
                )
              )
            )
            (list 
              (list "osmode" 0);关闭二维捕捉
              (list "cmdecho" 0) ;关闭回显
            )
          )
      );记录参数
      (if (not Global:TTSCVar) (setq Global:TTSCVar 200));初始值
    )
    (if
      (setq Global:TTSCVar 
            (cond
              ((getreal (strcat "\n→请输入目标比例:<" (rtos Global:TTSCVar) ">")))
              (Global:TTSCVar)
            )
      )
      (while 
        (and
          (princ "\n——★★★ 请选择非锁图层的块 ★★★——\n")
          (setq SS (ssget ":L" '((0 . "INSERT"))))
        )
        (repeat (setq i (sslength SS))
            (setq en (ssname SS (setq i (1- i)))
                  ent (Entget en )
            )
            (command "_.SCALE" en "" 
              (trans (Cdr (Assoc 10 ent)) 0 1);块基点
              (abs (/ Global:TTSCVar (Cdr (Assoc 41 ent))));取绝对值
            );缩放
        )
      )
    )
    (foreach xx *Old_SysVar* (apply 'setvar xx));参数恢复
  (vla-endundomark Doc) ;结束编组 
  (princ)
)
