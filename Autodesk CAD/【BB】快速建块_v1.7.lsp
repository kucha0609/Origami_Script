(progn ;基础函数
  (defun BB:GetMinBox (en / p1 p2 p3 p4 obj) 
    (vla-GetBoundingBox (setq obj (vlax-ename->vla-object en)) 'p1 'p3)
    (setq p1 (vlax-safearray->list p1)
          p3 (vlax-safearray->list p3)
          p2 (list (car p1) (cadr p3) (caddr p1))
          p4 (list (car p3) (cadr p1) (caddr p1))
    )
    (if (= "SPLINE" (cdr (assoc 0 (entget en)))) 
      (progn 
      (setq lst (mapcar 
                  '(lambda (a b) 
                      (vlax-curve-getClosestPointToProjection en a b t)
                    )
                  (list p1 p2 p3 p4)
                  '((1.0 0 0) (0 -1.0 0) (-1.0 0 0) (0 1.0 0))
                )
      )
      (list 
        (apply 'mapcar (cons 'min lst))
        (apply 'mapcar (cons 'max lst))
      )
      )
      (list p1 p3)
    )
  )
  (defun BB:GetCenter (ss / i Lst MinPt MaxPt)
      (repeat (setq i (sslength ss))
        (setq Lst (BB:GetMinBox (ssname ss (setq i (1- i)))))
        (setq 
            MinPt (mapcar 'min (car Lst) (cond (MinPt)((car Lst))))
            MaxPt (mapcar 'max (cadr Lst) (cond (MaxPt)((cadr Lst))))
        )
      );获取选择集最小外接矩形的WCS坐标
      (if (and MinPt MaxPt) 
        (mapcar 
          '(lambda (a b) (/ (+ a b) 2.0))
          MinPt
          MaxPt
        )
      )
  )
  (defun BB:GetBlkNam (/ BB:GetBlkNam i pre BlkNam)
      (defun BB:GetBlkNam (/ Old_Dim time yr mn dy hr mt sc)
          (setq Old_Dim (getvar "dimzin"))
          (setvar "dimzin" 0)
          (setq time (rtos (getvar "cdate") 2 20))
          (setq yr (substr time 3 2))
          (setq mn (chr (+ 65 (read (substr time 5 2)))));转大写字母  
          (setq dy (substr time 7 2))
          (setq hr (chr (+ 65 (read (substr time 10 2)))));转大写字母
          (setq mt (substr time 12 2))
          (setq sc (substr time 14 2))
          (setvar "dimzin" Old_Dim)
          (strcat mn "$" dy hr yr "-" mt sc )
      )
      (setq i 0)
      (setq pre (BB:GetBlkNam));前缀
      (setq BlkNam Pre)
      (while (tblsearch "BLOCK" BlkNam) 
          (setq BlkNam (strcat pre "-" (itoa (setq i (1+ i)))))
      );查找块名避免重复
      BlkNam
  )
)

(if (null vlax-dump-object) (vl-load-com));将Visual LISP扩展功能加载到 AutoLISP
(defun C:BB (/ *error* CurDoc *Old_SysVar* SS i pre BlkNam TgtPT *ent*) 
  (setq CurDoc (vla-get-activedocument (vlax-get-acad-object)))
  (defun *error* (x) ;出错函数
    (if *Old_SysVar* (foreach xx *Old_SysVar* (apply 'setvar xx))) ;参数恢复
    (vla-endundomark CurDoc) ;结束编组
  )

  (while (eq 8 (logand 8 (getvar 'undoctl))) 
    (vla-endundomark CurDoc)
  ) ;关闭以前的编组
  (vla-startundomark CurDoc) ;记录编组
      (progn ;记录系统变量及设置初始值
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
                (list "cmdecho" 0) ;关闭回显
              )
            )
        );记录参数

        (if (not Global:MoveType) (setq Global:MoveType 1)) ;1块不归零,-1块归零
      )
      (if (eq 4 (logand 4 (cdr (assoc 70 (tblsearch "LAYER" (getvar "CLAYER"))))))
          (alert (strcat "※当前图层已锁定, 无法运行程序！"))
          (progn
              (princ "\n——★★★ 回车使用选择集中心作为块基点 ★★★——")
              (while (setq SS (ssget ":L"))
                  (progn
                      (setq BlkNam (BB:GetBlkNam))
                      (setq TgtPT nil)
                      (while ;get*
                      (progn 
                          (initget (+ 2 4) "S") ;非零非负关键词
                          (setq TmpPT (getpoint (strcat "\n→请指定点[" (if (= Global:MoveType 1) "不" "") "归零(S)]")))
                          (cond 
                          ((and TmpPT (eq (type TmpPT) 'LIST));指定了点
                              (setq TgtPT (trans TmpPT 1 0))
                              Nil ;退出循环
                          )
                          ((and (eq (type TmpPT) 'STR)(eq (strcase TmpPT) "S"));字母S
                              (setq Global:MoveType (* -1 Global:MoveType)) ;1/-1
                              T ;继续循环
                          )
                          (T
                              (setq TgtPT (BB:GetCenter ss))
                              Nil ;退出循环
                          )
                          )
                      )
                      )
                      (if TgtPT
                          (progn
                              (command "_.block" BlkNam "non" (trans TgtPT 0 1) SS "")
                              (command "_.Insert" BlkNam "non" (trans TgtPT 0 1) "" "" "")

                              (if (and
                                  (= Global:MoveType -1)
                                  (setq *ent* (entget (entlast)))
                                  )
                                  (entmod  (subst (cons 8 "0") (assoc 8 *ent*) *ent*))
                              )
                              (princ (strcat "\n——★★★ 已创建块<" BlkNam "> ★★★——"))
                          )
                      )
                  )
              )
          )
      )
      (command "redraw")
      (if *Old_SysVar* (foreach xx *Old_SysVar* (apply 'setvar xx))) ;参数恢复
  (vla-endundomark CurDoc) ;结束编组
  (command "redraw")
  (princ)
)

