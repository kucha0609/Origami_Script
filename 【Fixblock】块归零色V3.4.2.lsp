(if (null vlax-dump-object) (vl-load-com));将Visual LISP扩展功能加载到 AutoLISP

(setq Global:ignLayLst (list "BlkUnPlt"));排除的图层
; Global:HatchCol 填充的颜色
; Global:ObjCol 对象的默认颜色
; Global:IgnLay 忽略排除层

(progn ;基础函数
    ;|带关键字的ssget[在Fsxm大神的源码基础上完善@1028695446]
        Msg 提示信息
        Kwd 选项关键字
            支持多个关键字，如":E:S S",关键字之间用空格隔开，其中"S"为额外选项关键字（应摒避CAD内置于SSGET中的关键字）
        Fil 选集过滤表

        返回:选集或额外选项关键字
        优化内容1：支持(ssget ":E:S")模式
        优化内容2：完善原程序在先选择后执行情况下，不过滤的bug
    |;
    (defun Fix:Key4ssget (Msg Kwd Fil / Pt2Str LM:STR->Lst Fsxm-entsel Kwd0 pt var stop result  key_ssget)
        (progn
            ;点转字符串
            (defun Pt2Str (pt)
                (strcat (rtos (car pt) 2 20) "," (rtos (cadr pt) 2 20) "," (rtos (caddr pt) 2 20) "\n")
            )
            ;根据分隔符拆分字符串@LeeMac
            (defun LM:STR->Lst (STR Del / len Lst pos) 
                (setq len (1+ (strlen Del)))
                (while (setq pos (vl-string-search Del STR)) 
                  (setq Lst (cons (substr STR 1 pos) Lst)
                        STR (substr STR (+ pos len))
                  )
                )
                (reverse (cons STR Lst))
            )
            (defun Fsxm-entsel (msg filter / enp)
                (setq enp (entsel msg))
                (if 
                    (or 
                        (= (type enp) 'str)
                        (and enp (ssget (cadr enp) filter)) ;;点选
                    )
                    enp
                )
            )
        )
        (cond 
          ((cadr (ssgetfirst)) 
              (command "SELECT" (cadr (ssgetfirst)) "")
              (setq result (ssget "P" Fil))
          );优化内容2：完善原程序在先选择后执行情况下，不过滤的bug，
          (t
              (setq Kwd0 "W L C BOX ALL F WP CP G A R M P U AU SI")
              (setq kwd (strcase kwd))
              (setq kwd_lst (LM:STR->Lst kwd " "))
              (initget (strcat Kwd0 " " kwd))
              (setq var (fsxm-entsel Msg Fil))
              (if (OR (member "SI" kwd_lst) (member ":S" kwd_lst))
                  (if (and var (listp var)) 
                    (progn 
                      (setq stop T)
                      (setq result (ssadd (car var)))
                    )
                  )
              );优化内容1：支持(ssget ":E:S")模式
              (if (NOT stop) 
                (cond 
                  ((and 
                      (listp var) ;;说明Fsxm-entsel空选
                      (/= 52 (getvar "errno"))
                    )
                    (vla-sendcommand 
                        (vla-get-ActiveDocument (vlax-get-acad-object)) 
                        (Pt2Str (cadr (grread t)))
                    )
                    (setq key_lst (list ":E" "M" ":S" "SI" ":E:S" ":S:E" ":L"))
                    (foreach x kwd_lst 
                        (if (member x key_lst) 
                          (cond 
                            ((or (= x ":E") (= x "M")) (setq key_ssget ":E"))
                            ((or (= x ":S") (= x "SI")) (setq key_ssget ":S"))
                            ((or (= x ":E:S") (= x ":S:E") (= x ":L")) (setq key_ssget x))
                          )
                        )
                    )
                    (if key_ssget 
                        (setq result (ssget key_ssget Fil))
                        (setq result (ssget Fil))
                    ) ;;更新修正2022.5.12
                  ) ;;空选之后变框选
                  ((member var (LM:STR->Lst Kwd0 " "))
                      (vla-sendcommand (vla-get-ActiveDocument (vlax-get-acad-object)) (strcat var "\n"))
                      (setq result (ssget Fil))
                  ) ;响应用户手动输入的关键字（选择模式）
                  (t (setq result var))
                )
              )
          )
        )
        result
    )
  
    ;新建图层：图层名称、图层颜色、是否打印(:vlax-false不打印，:vlax-true打印)
    (defun Fix:GetNewLay (LayNam Col Plt / TgtEn TgtObj) 
      ;若图层不存在则新建。若存在则检查图层更新颜色和打印状态。
      (if (setq TgtEn (tblobjname "layer" LayNam)) 
          (progn  ;更新参数
              (setq TgtObj (vlax-ename->vla-object TgtEn))
              (vla-put-color TgtObj Col) ;更新颜色
              (vla-put-Plottable TgtObj Plt) ;更新可打印状态
          )
          (entmake  ;新建图层
            (list 
              (cons 0 "LAYER")
              (cons 100 "AcDbSymbolTableRecord")
              (cons 100 "AcDbLayerTableRecord")
              (cons 70 0) ;层可见性
              (cons 2 LayNam) ;图层名称
              (cons 62 Col) ;图层颜色
              (cons 290 (if (eq Plt :vlax-false) 0 1)) ;是否打印(0不打印，1打印)
            )
          )
      )
    )
    ;子功能：更新属性块内的文字
    (defun Fix:AttUpd (obj BlkLay / XX AttLst) 
        (if 
            (listp 
              (setq AttLst (vl-catch-all-apply 'vlax-invoke (list obj 'getAttributes)))
            )
            (mapcar 
              (function (lambda (XX) (Fix:EditProp XX BlkLay)))
              AttLst
            )
        )
    )

    ;子功能：设置对象特性
    (defun Fix:EditProp (obj BlkLay / lt Lay RGBCol) 
        (setq Lay
            (if (eq (vla-get-Layer obj) "0")
                BlkLay
                (vla-get-Layer obj)
            );获取对象图层(处理块内)
        )
        (if Global:IgnLay
              (progn
                  (vla-put-Layer obj "0")
                  (if (= (Vlax-Get obj 'ObjectName ) "AcDbHatch")
                      (vla-put-Color obj Global:HatchCol)
                      (if (vl-catch-all-error-p (vl-catch-all-apply 'vla-put-Color (list obj Global:ObjCol)))
                          (progn
                              (setq RGBCol (vla-get-TrueColor obj))
                              (vlax-put-property RGBCol 'ColorIndex Global:ObjCol)
                              (vla-put-TrueColor obj RGBCol)
                          )
                      )
                  );颜色
              );忽略了图层
              (if (not (member Lay Global:ignLayLst))
                  (if (eq :vlax-false (vla-get-Plottable (vla-item (vla-get-Layers CurDoc) Lay)));图层不可印
                      (progn
                          (vla-put-Layer obj "BlkUnPlt")
                          (if (vl-catch-all-error-p (vl-catch-all-apply 'vla-put-Color (list obj acByLayer)))
                              (progn
                                  (setq RGBCol (vla-get-TrueColor obj))
                                  (vlax-put-property RGBCol 'ColorIndex acByLayer)
                                  (vla-put-TrueColor obj RGBCol)
                              )
                          );颜色
                      )
                      (progn
                          (vla-put-Layer obj "0")
                          (if (= (Vlax-Get obj 'ObjectName ) "AcDbHatch")
                              (vla-put-Color obj Global:HatchCol)
                              (if (vl-catch-all-error-p (vl-catch-all-apply 'vla-put-Color (list obj Global:ObjCol)))
                                  (progn
                                      (setq RGBCol (vla-get-TrueColor obj))
                                      (vlax-put-property RGBCol 'ColorIndex Global:ObjCol)
                                      (vla-put-TrueColor obj RGBCol)
                                  )
                              )
                          );颜色
                      )
                  )
              )
        );颜色和图层
    )
    ;主程序：嵌套递归处理
    (defun Fix:editblock (obj BlkLay / Nam1 blkobj Nam2)
        (foreach Nam1
            (if (vlax-property-available-p obj 'EffectiveName);动态块
                (list (vla-get-Name obj) (vla-get-EffectiveName obj))
                (list (vla-get-Name obj) )
            );块名(含动态块)
            (progn
                (Fix:AttUpd obj BlkLay);属性文字
                (vlax-for blkobj (vla-item OriBlk Nam1)
                    (if 
                        (and
                            (wcmatch (vla-get-objectname blkobj) "*Block*");是块
                            (not (member (vla-get-Name blkobj) TgtLst))
                        )
                        (progn
                            (Fix:AttUpd blkobj BlkLay);属性文字
                            (foreach Nam2
                                (if (vlax-property-available-p blkobj 'EffectiveName);动态块
                                    (list (vla-get-Name blkobj) (vla-get-EffectiveName blkobj))
                                    (list (vla-get-Name blkobj))
                                );块名(含动态块)
                                (if (not (member Nam2 TgtLst))
                                    (progn
                                        (Fix:editblock (vla-item OriBlk Nam2) 
                                            (if (eq (vla-get-Layer blkobj) "0")
                                                BlkLay
                                                (vla-get-Layer blkobj)
                                            )
                                        );递归处理
                                        (setq TgtLst (cons Nam2 TgtLst))
                                    )
                                )
                            )
                        );块中块
                        (Fix:EditProp blkobj BlkLay)
                    )
                );块内
                (if (not (member Nam1 TgtLst))
                    (setq TgtLst (cons Nam1 TgtLst))
                )
            )
        );块本身  
    )
)
(defun C:FixBlock (/ *error* CurDoc OriBlk OriLay *Old_SysVar* *LockLst* TmpVar TgtSS OthSS TgtLst objLst i obj) 
    (setq CurDoc (vla-get-activedocument (vlax-get-acad-object))
          OriBlk (vla-get-Blocks CurDoc)
          OriLay (vla-get-Layers CurDoc)
    )
    (defun *error* (x)  ;出错函数
      (if *LockLst* 
        (mapcar (function (lambda (XX) (vla-put-lock XX :vlax-true))) *LockLst*)
      )
      (if *Old_SysVar* (foreach xx *Old_SysVar* (apply 'setvar xx)));参数恢复
      (vla-endundomark CurDoc) ;错误时结束编组
    )

    (while (eq 8 (logand 8 (getvar 'undoctl))) 
      (vla-endundomark CurDoc)
    ) ;关闭以前的编组
    (vla-startundomark CurDoc) ;记录编组
      (progn ;记录系统变量
          (setq *Old_SysVar* '());清空变量,避免出错
          (setq *Old_SysVar* 
              (mapcar 
                (function 
                  (lambda (a / b) 
                  (if (setq b (getvar (car a)))
                      (progn 
                        (vl-catch-all-apply 'setvar a)
                        (list (car a) b)
                      )
                  )
                  )
                )
                (list 
                  (list "DIMZIN" 0);保留前导和后续的零
                  (list "CMDECHO" 0) ;关闭回显
                )
              )
          );记录参数
        
          (if (not Global:HatchCol)(setq Global:HatchCol 250));填充的颜色
          (if (not Global:ObjCol)(setq Global:ObjCol 0));对象的默认颜色
          (setq Global:IgnLay nil);始终排除层
        
          (Fix:GetNewLay "BlkUnPlt" 1 :vlax-false);不可打印图层
      )
    
      (vlax-for XX (vla-get-Layers CurDoc) 
          (if (= :vlax-true (vla-get-lock XX)) 
              (progn 
                (vla-put-lock XX :vlax-false)
                (setq *LockLst* (cons XX *LockLst*))
              )
          )
      );临时解锁图层并记录
      (if (setq TmpVar (acad_colordlg Global:ObjCol))
          (progn
              (setq Global:ObjCol TmpVar)
              (while 
                (progn 
                  (setq TgtSS 
                      (Fix:Key4ssget 
                          (strcat
                              "请选择块或 [填充色(S)_"
                              (rtos Global:HatchCol 2 0)
                              (if Global:IgnLay "/不排除(D)" "/排除层(D)")
                              "]："
                          )
                          "S s D d"
                          (list '(0 . "INSERT"))
                      )
                  )
                  (cond 
                    ((and (= 'str (type TgtSS)) (= "S" (strcase TgtSS)))
                        (if (setq TmpVar (acad_colordlg Global:HatchCol))
                            (setq Global:HatchCol TmpVar) ;默认250色
                        )
                        T ;继续循环
                    )
                    ((and (= 'str (type TgtSS)) (= "D" (strcase TgtSS)))
                        (setq Global:IgnLay (not Global:IgnLay))
                        T ;继续循环
                    )
                    (TgtSS
                        (progn 
                          (setq TgtLst nil objLst nil)
                          (progn
                              (repeat (setq i (sslength TgtSS)) 
                                  (setq obj (vlax-ename->vla-object  (ssname TgtSS (setq i (1- i)))))
                                  (if 
                                      (and
                                          (wcmatch (vla-get-objectname obj) "*Block*");是块
                                          (=
                                            :vlax-false
                                            (vla-get-isXref (vla-item OriBlk (vla-get-Name obj)))
                                          );不是外部参照(也不会是动态块)
                                      )
                                      (progn
                                          (setq objLst (cons obj objLst))
                                          (Fix:editblock obj  (Vlax-Get obj 'layer))
                                      )
                                  )
                              )
                              (if
                                  (and
                                      (setq TgtLst
                                            (vl-remove-if 
                                              (function (lambda (XX) (wcmatch XX "`*U*")));`转义*,排除匿名块，动态块
                                              TgtLst
                                            )
                                      )
                                      (setq OthSS (ssget "A"
                                                    (append
                                                        (list 
                                                            (cons -4 "<AND")
                                                            (cons 0 "INSERT")
                                                            (cons -4 "<OR")
                                                        )
                                                        (mapcar (function (lambda (XX) (cons 2 XX))) TgtLst)
                                                        (list 
                                                            (cons -4 "OR>")
                                                            (cons -4 "AND>")
                                                        )
                                                    )
                                          )
                                      )
                                  )
                                  (progn
                                      (setq TgtLst nil)
                                      (repeat (setq i (sslength OthSS)) 
                                          (setq obj (vlax-ename->vla-object  (ssname OthSS (setq i (1- i)))))
                                          (if 
                                              (and
                                                  (wcmatch (vla-get-objectname obj) "*Block*");是块
                                                  (=
                                                    :vlax-false
                                                    (vla-get-isXref (vla-item OriBlk (vla-get-Name obj)))
                                                  );不是外部参照(也不会是动态块)
                                                  (not (member obj objLst));没有处理过
                                              )
                                              (Fix:editblock obj (Vlax-Get obj 'layer)) 
                                          ) 
                                      )
                                  )
                              )
                          )
                        )
                        (vla-Regen CurDoc 1)
                    )
                    (T
                      (princ "\n——★★★ 请输入正确的关键词或 ESC退出！ ★★★——\n")
                      T ;继续循环
                    )
                  )
                )
              );循环
              (vla-Regen CurDoc acAllViewports)
            
                (princ (strcat 
                        "\n——★★★ 块内归零改色@Kucha：填充改<"
                        (rtos Global:HatchCol 2 0) 
                        ">色 ★★★——\n"
                    )
                )
          )
      )
      (if *LockLst* 
          (mapcar (function (lambda (XX) (vla-put-lock XX :vlax-true))) *LockLst*)
      );图层重新锁定
      (command "redraw");清空一行
      (if *Old_SysVar* (foreach xx *Old_SysVar* (apply 'setvar xx)));参数恢复
  
    (vla-endundomark CurDoc) ;结束编组
    (princ)
)

(if (not (getenv "K\\ToolsIsExit"))
    (princ "\n——★★★ 块内归零改色,由Kucha开发(QQ1365859796)。调用命令: FixBlock ★★★——\n")
)(princ)