;|
  *图层管理：采用数字+汉语拼音简写的方式来调用对应的图层状态。                                          
    →命令一:GBTC=1=关闭图层    TCQK=2=图层全开    SDTC=3=锁定图层    JSTC=4=解锁图层
    →命令二:GBQT=5=关闭其它    SDQT=6=锁定其它    HFTC=7=恢复图层
    →命令三:ZWDQ=8=置为当前    YZDQ=9=移至当前    XZLS=0=选择类似

|;

(progn ;基础函数
  ;判断提示的语言是简体中文还是英文？Flag为T时使用警告alert
  (defun K:LangTips (Flag CN EN / Tmp)
    (setq Tmp (strcase (getvar "syscodepage")))
    (if 
      (or 
        (eq Tmp (strcase "ANSI_936")) ;简体中文
        (eq Tmp (strcase "ANSI_950")) ;繁体中文
      )
      (if Flag
          (alert CN)
          (if CN (princ (strcat "\n——★★★ " CN " ★★★——\n")))  
      )
      (if Flag
          (alert EN)
          (if EN (princ (strcat "\n——★★★ " EN " ★★★——\n")))
      )
    )
    (princ)
  )
  ;如果属性存在就获取
  (defun K:GetProp (Obj Func)
    (setq Func (if (= 'SYM (type Func)) Func (function Func)))
    (if (vlax-property-available-p Obj Func);存在
        (vlax-Get Obj Func)
    )
  )
  ;如果属性存在且可修改就赋予
  (defun K:PutProp (Obj Func Var)
    (setq Func (if (= 'SYM (type Func)) Func (function Func)))
    (if (and
          (vlax-write-enabled-p obj);对象可修改
          (vlax-property-available-p Obj Func T);存在且可修改
          (not (null Var));不为Nil
        )
        (not (vlax-put Obj Func Var));修改成功返回T
    )
  )
  ;新建图层：图层名称、图层颜色、是否打印(:vlax-false不打印，:vlax-true打印)
  (defun K:NLayNlock (LayNam Col Plt / TgtEn TgtObj) 
    ;若图层不存在则新建。若存在则检查图层更新颜色和打印状态。
    (if (setq TgtEn (tblobjname "layer" LayNam)) 
        (progn  ;更新参数
            (setq TgtObj (vlax-ename->vla-object TgtEn))
            ;(vla-put-color TgtObj Col) ;更新颜色
            (vla-put-Plottable TgtObj Plt) ;更新可打印状态
            (vla-put-Lock TgtObj :vlax-false) ;解锁图层

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
  ;选择集转对象表@LeeMac
  (defun K:SS->ObjLst (SS / i ObjLst) 
    (if SS 
      (repeat (setq i (sslength SS)) 
        (setq ObjLst (cons (vlax-ename->vla-object (ssname SS (setq i (1- i)))) ObjLst))
      )
    )
  )
  ;获取实体的线型名称，如果没有就获取其图层的
  (defun K:GetLType4En (en) 
      (if (assoc 6 (entget en))
        (cdr (assoc 6 (entget en)))
        (cdr (assoc 6 (tblsearch "layer" (cdr (assoc 8 (entget en))))))
      )
  )
)


;8+9
  ;Global:AllDimSca 全局标注比例
  (defun C:ZWDQ (/ CurDoc *Old_SysVar* TgtSS TgtObj TgtLay)
    (setq CurDoc (vla-get-activedocument (vlax-get-acad-object)))
    (defun *error* (x)  ;出错函数
      (if *Old_SysVar* (foreach xx *Old_SysVar* (apply 'setvar xx)) );参数恢复
      (vla-endundomark CurDoc) ;错误时结束编组
    )

    (while (eq 8 (logand 8 (getvar 'undoctl))) 
      (vla-endundomark CurDoc)
    ) ;关闭以前的编组
    (vla-startundomark CurDoc) ;记录编组
      (progn ;基础变量
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
                (list "DIMZIN" 0) ;不消除后导零
                (list "cmdecho" 0) ;关闭回显
              )
            )
        );记录参数
        (setq Global:AllDimSca
            (if (and (not Global:AllDimSca)  (equal (getvar "DIMSCALE") 1.0 1e-6))
                (setvar "DIMSCALE" 50)
                (getvar "DIMSCALE")
            )
        );默认标注比例
      )
      (while (not (and (setq TgtSS (ssget ":S:E")) (eq 1 (sslength TgtSS))))
          (princ (strcat "\n——★★★ 请选择单一个对象！ ★★★——\n"))    
      )
      (if
          (setq TgtObj (vlax-ename->vla-object (ssname TgtSS 0));对象名
                TgtLay (K:GetProp TgtObj 'Layer);层名
          ) 
          (progn
              (setvar "CLAYER" TgtLay);图层置为当前
              (cond
                  ((wcmatch (K:GetProp TgtObj 'ObjectName) "TDb*")
                      (setq Global:AllDimSca (K:GetProp TgtObj 'scale));天正对象的标注比例
                  )
                  ((wcmatch (K:GetProp TgtObj 'ObjectName) "*Dimension*")
                      (setq Global:AllDimSca (K:GetProp TgtObj 'ScaleFactor));CAD对象的标注比例
                  )
                  ((wcmatch (K:GetProp TgtObj 'ObjectName) "AcDbHatch")
                      (setq Global:AllDimSca (K:GetProp TgtObj 'PatternScale));CAD填充的标注比例
                  )
                  ((member 
                     (K:GetLType4En (vlax-vla-object->ename TgtObj))
                     (list "DD" "D0" "D1" "D2" "D3")
                   )
                      (setq Global:AllDimSca (K:GetProp obj 'LinetypeScale));线型比例
                  )
              )
              (setvar "DIMSCALE" Global:AllDimSca);设置CAD标注比例
              (if (eval (read "TsetPScale"));存在天正命令
                  (TsetPScale Global:AllDimSca) ;设置天正比例
              )
              (princ (strcat "\n——★★★ 当前图层为<" TgtLay ">，标注比例为<" (rtos Global:AllDimSca 2 2) "> ★★★——\n"))
          )
      )
      (command ".redraw")
      (if *Old_SysVar* (foreach xx *Old_SysVar* (apply 'setvar xx)) );参数恢复
    (vla-endundomark CurDoc) ;结束编组
    (princ)
  );将所选对象所在的图层置为当前图层
  (defun C:YZDQ (/ *error* CurDoc *Old_SysVar* SS i obj  TmpVar AenLst) 
    (setq CurDoc (vla-get-activedocument (vlax-get-acad-object)))
    (defun *error* (x)  ;出错函数
      (if *Old_SysVar* (foreach xx *Old_SysVar* (apply 'setvar xx)) );参数恢复
      (vla-endundomark CurDoc) ;错误时结束编组
    )
    (while (eq 8 (logand 8 (getvar 'undoctl))) 
      (vla-endundomark CurDoc)
    ) ;关闭以前的编组
    (vla-startundomark CurDoc) ;记录编组
      (progn ;基础变量
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
                (list "DIMZIN" 0) ;不消除后导零
                (list "cmdecho" 0) ;关闭回显
              )
            )
        );记录参数

        (setq Global:AllDimSca
            (if (and (not Global:AllDimSca)  (equal (getvar "DIMSCALE") 1.0 1e-6))
                (setvar "DIMSCALE" 50)
                (getvar "DIMSCALE")
            )
        );默认标注比例
        (K:NLayNlock "PUB_DIM" 3 :vlax-true);新建图层绿色可打印
      )
      
      (if (null (last (ssgetfirst)));没有预选对象
          (princ (strcat "\n——★★★ 当前图层为<" (getvar "CLAYER") ">，标注比例为<" (rtos Global:AllDimSca 2 1) "> ★★★——\n")) 
      )
      (if (and (setq SS (ssget ":L"))(setq SSObjLst (K:SS->ObjLst SS)))
          (if (vl-remove-if-not '(lambda (XX) 
                                   (or
                                      (member (K:GetProp XX 'ObjectName) 
                                        (list "AcDbAlignedDimension" "AcDbArcDimension" "AcDbRadialDimension" "AcDb2LineAngularDimension" "AcDb3PointAngularDimension" "AcDbText")
                                      );CAD标注和文字
                                      (wcmatch (K:GetProp XX 'ObjectName) "TDb*");天正对象
                                  )
                                 ) SSObjLst);对齐+弧长+半径标注+单行文字
              (progn
                  (princ (strcat "\n——★★★ 所选对象包含：对齐+弧长+半径标注+角度标注+单行文字，请输入比例 ★★★——\n")) 
                  (while ;get*
                    (progn 
                      (progn
                          (initget (+ 2 4) "C") ;非零非负关键词
                          (setq TmpVar 
                              (cond
                                  ((getreal (strcat "\n→请输入标注比例或空格 [仅移至当前(C)]<" (rtos Global:AllDimSca 2 1) ">")))
                                  (Global:AllDimSca);回车使用上次的值
                              )
                          )
                      )
                      (cond 
                        ((and TmpVar (member (type TmpVar) (list 'Real 'INT)));是实数或者整数
                            (setq AenLst nil)
                            (foreach obj SSObjLst
                                (cond
                                  ((member (K:GetProp obj 'ObjectName) (list "AcDbAlignedDimension" "AcDbArcDimension" "AcDbRadialDimension" "AcDb2LineAngularDimension" "AcDb3PointAngularDimension"));对齐+弧长+半径标注+角度标注
                                    (K:PutProp obj 'Layer "PUB_DIM");移动到标注层
                                    (setq AenLst (cons (vlax-vla-object->ename obj) AenLst))
                                  )
                                  ((eq (K:GetProp obj 'ObjectName) "AcDbText");单行文字
                                    (K:PutProp obj 'Height (* TmpVar 3.5))
                                    ;(K:PutProp obj 'Layer (getvar "CLAYER"))
                                  )
                                  ((wcmatch (K:GetProp obj 'ObjectName) "TDb*");天正对象
                                    (K:PutProp obj 'Scale TmpVar);修改标注比例
                                  )
                                  (t nil)
                                )
                                (if (and
                                      (eq (K:GetProp obj 'Layer) "PUB_DIM");标注层
                                      (member (K:GetLType4En (vlax-vla-object->ename obj)) (list "DD" "D0" "D1" "D2" "D3"))
                                    )
                                    (K:PutProp obj 'LinetypeScale TmpVar)
                                );线型比例
                            );修改图层和线型比例
                            (Sub:FixSca4Dim Nil AenLst TmpVar);修改收集到的标注比例
                            (setvar "DIMSCALE" TmpVar);设置CAD标注比例
                            (if (eval (read "TsetPScale"));存在天正命令
                                (TsetPScale TmpVar) ;设置天正比例
                            )
                            (princ (strcat "\n——★★★ 标注对象的比例已调整为<" (rtos TmpVar 2 1) "> ★★★——\n")) 
                            Nil ;退出循环
                        )
                        ((and (eq (type TmpVar) 'STR)(eq (strcase TmpVar) "C"));字母C
                          (foreach obj SSObjLst
                              (K:PutProp obj 'Layer (getvar "CLAYER"))
                              (if (and
                                    (eq (K:GetProp obj 'Layer) "PUB_DIM");标注层
                                    (member (K:GetLType4En (vlax-vla-object->ename obj)) (list "DD" "D0" "D1" "D2" "D3"))
                                  )
                                  (K:PutProp obj 'LinetypeScale Global:AllDimSca)
                              );线型比例
                          );修改图层和线型比例
                          (princ (strcat "\n——★★★ 所选对象已移至当前层<" (getvar "CLAYER") "> ★★★——\n")) 
                          Nil ;退出循环
                        )
                        (T Nil);退出循环
                      )
                    )
                  )
              )
              (progn
                (foreach obj SSObjLst
                    (K:PutProp obj 'Layer (getvar "CLAYER"))
                    (if (and
                          (eq (K:GetProp obj 'Layer) "PUB_DIM");标注层
                          (member (K:GetLType4En (vlax-vla-object->ename obj)) (list "DQ1000" "DQ100" "DQ10" "DQ1" "DD" "D0" "D1" "D2" "D3"))
                        )
                        (K:PutProp obj 'LinetypeScale Global:AllDimSca)
                    );线型比例
                );修改图层和线型比例
                (princ (strcat "\n——★★★ 所选对象已移至当前层<" (getvar "CLAYER") "> ★★★——\n")) 
              )
          )
      )

      (command ".redraw")
      (if *Old_SysVar* (foreach xx *Old_SysVar* (apply 'setvar xx)) );参数恢复
    (vla-endundomark CurDoc) ;结束编组
    (princ)
  );移动所选对象到当前图层
;
;0~7
  ;GBTC-关闭图层，支持框选
  (defun C:GBTC (/ CurDoc OLD_CMD LAYLST SS I ENT OBJLAY LAYNAM )
    (setq CurDoc (vla-get-activedocument (vlax-get-acad-object)))
    (progn ;基础函数
        (if (ssget "i");是否预选对象
            (setq SS (ssget))
            (progn
                (K:LangTips Nil "请选择需要关闭的图层上的对象" "Select the object on the layer to be turned off")
                (setq SS (ssget))
            )
        )
        (defun *error*(Msg)
            (setvar "cmdecho" OLD_CMD)
            (vla-endundomark CurDoc);错误时结束编组
            (princ)
        )	
        (setq OLD_CMD (getvar "cmdecho"))
        (setq LayLst (vla-get-layers CurDoc))
    )

    (while (eq 8 (logand 8 (getvar 'undoctl))) 
        (vla-endundomark CurDoc)
    );关闭以前的编组
    (vla-startundomark CurDoc);记录编组
      (setvar "cmdecho" 0)
      (if SS
        (progn
          (repeat (setq i (sslength SS))
              (setq ent    (ssname SS (setq i (1- i)))
                    ObjLay (cdr (assoc 8 (entget ent)))
                    LayNam (vla-item LayLst ObjLay)
              )
              (vla-put-layeron LayNam :vlax-false);显示图层
          )
          (K:LangTips Nil "已关闭所选对象所在的图层" "The layer of the selected object has been turned off")
        )
      )
      (command "redraw")
      (setvar "cmdecho" OLD_CMD)
    (vla-endundomark CurDoc);结束编组
    (princ)
  )
  ;TCQK-显示全部图层
  (defun C:TCQK (/ CurDoc OLD_CMD LAYLST)
    
    (setq CurDoc (vla-get-activedocument (vlax-get-acad-object)))
    (progn ;基础函数
        (defun *error*(Msg)
            (setvar "cmdecho" OLD_CMD)
            (vla-endundomark CurDoc);错误时结束编组
            (princ)
        )	
        (setq OLD_CMD (getvar "cmdecho"))
        (setq LayLst (vla-get-layers CurDoc))
    )

    (while (eq 8 (logand 8 (getvar 'undoctl))) 
        (vla-endundomark CurDoc)
    );关闭以前的编组
    (vla-startundomark CurDoc);记录编组
      (setvar "cmdecho" 0)
      (vlax-for XX LayLst (vla-put-layeron XX :vlax-true));图层全开
      (K:LangTips Nil "所有图层均已开启显示" "All layers have been turned on")
      (command "redraw")
      (setvar "cmdecho" OLD_CMD)
    (vla-endundomark CurDoc);结束编组
    (princ)
  )


  ;SDTC-锁定图层，支持框选
  (defun C:SDTC (/ CurDoc OLD_CMD LAYLST SS I ENT OBJLAY)
    (setq CurDoc (vla-get-activedocument (vlax-get-acad-object)))
    (progn ;基础函数
        (if (ssget "i");是否预选对象
            (setq SS (ssget))
            (progn
                (K:LangTips Nil "请选择需要锁定的图层上的对象" "Select the object on the layer to be locked")
                (setq SS (ssget))
            )
        )
        (defun *error*(Msg)
            (setvar "cmdecho" OLD_CMD)
            (vla-endundomark CurDoc);错误时结束编组
            (princ)
        )	
        (setq OLD_CMD (getvar "cmdecho"))
        (setq LayLst (vla-get-layers CurDoc))
    )

    (while (eq 8 (logand 8 (getvar 'undoctl))) 
        (vla-endundomark CurDoc)
    );关闭以前的编组
    (vla-startundomark CurDoc);记录编组
      (setvar "cmdecho" 0)
      (if SS
        (progn
            (repeat (setq i (sslength SS))
                (setq ent (ssname SS (setq i (1- i)))
                      ObjLay (cdr (assoc 8 (entget ent)))
                )
                (command "_.layer" "lo" ObjLay "")
            )
            (K:LangTips Nil "已锁定所选对象所在的图层" "The layer of the selected object has been locked")
        )
      )
      (command "redraw")
      (setvar "cmdecho" OLD_CMD)
    (vla-endundomark CurDoc);结束编组
    (princ)
  )
  ;JSTC-解锁全部图层
  (defun C:JSTC (/ CurDoc OLD_CMD)
    (setq CurDoc (vla-get-activedocument (vlax-get-acad-object)))
    (progn ;基础函数
        (defun *error*(Msg)
            (setvar "cmdecho" OLD_CMD)
            (vla-endundomark CurDoc);错误时结束编组
            (princ)
        )	
        (setq OLD_CMD (getvar "cmdecho"))
    )
    (while (eq 8 (logand 8 (getvar 'undoctl))) 
        (vla-endundomark CurDoc)
    );关闭以前的编组
    (vla-startundomark CurDoc);记录编组
      (setvar "cmdecho" 0)
      (command "_.layer" "U" "*" "");解锁全部图层
      (K:LangTips Nil "所有图层均已解锁" "All layers have been unlocked")
      (command "redraw")
      (setvar "cmdecho" OLD_CMD)
    (vla-endundomark CurDoc);结束编组
    (princ)
  )

  ;GBQT-关闭其它图层,支持框选
  (defun C:GBQT (/ CurDoc OLD_CMD LAYLST SS I ENT OBJLAY LAYNAM )
    (setq CurDoc (vla-get-activedocument (vlax-get-acad-object)))
    (progn ;基础函数
        (if (ssget "i");是否预选对象
            (setq SS (ssget))
            (progn
                (K:LangTips Nil "请选择不需要关闭的图层上的对象" "Select the object on the layer not to be turned off")
                (setq SS (ssget))
            )
        )
        (defun *error*(Msg)
            (setvar "cmdecho" OLD_CMD)
            (vla-endundomark CurDoc);错误时结束编组
            (princ)
        )
        (setq OLD_CMD (getvar "cmdecho"))
        (setq LayLst (vla-get-layers CurDoc))
    )

    (while (eq 8 (logand 8 (getvar 'undoctl))) 
        (vla-endundomark CurDoc)
    );关闭以前的编组
    (vla-startundomark CurDoc);记录编组
      (setvar "cmdecho" 0)
      (if SS
        (progn
          (vlax-for XX LayLst (vla-put-layeron XX :vlax-false));图层全关
          (repeat (setq i (sslength SS))
              (setq ent    (ssname SS (setq i (1- i)))
                    ObjLay (cdr (assoc 8 (entget ent)))
                    LayNam (vla-item LayLst ObjLay)
              )
              (vla-put-layeron LayNam :vlax-true);显示图层
          )
          (K:LangTips Nil "已关闭除所选对象图层外的其它图层" "The layer other than the selected object layer has been turned off")
        )
      )
      (command "redraw")
      (setvar "cmdecho" OLD_CMD)
    (vla-endundomark CurDoc);结束编组
    (princ)
  )
  ;SDQT-锁定其它图层,支持框选
  (defun C:SDQT (/ CurDoc OLD_CMD LAYLST SS I ENT OBJLAY)
    (setq CurDoc (vla-get-activedocument (vlax-get-acad-object)))
    (progn ;基础函数
        (if (ssget "i");是否预选对象
            (setq SS (ssget))
            (progn
                (K:LangTips Nil "请选择不需要锁定的图层上的对象" "Select the object on the layer not to be locked")
                (setq SS (ssget))
            )
        )
        (defun *error*(Msg)
            (setvar "cmdecho" OLD_CMD)
            (vla-endundomark CurDoc);错误时结束编组
            (princ)
        )	
        (setq OLD_CMD (getvar "cmdecho"))
        (setq LayLst (vla-get-layers CurDoc))
    )

    (while (eq 8 (logand 8 (getvar 'undoctl))) 
        (vla-endundomark CurDoc)
    );关闭以前的编组
    (vla-startundomark CurDoc);记录编组
      (setvar "cmdecho" 0)
      (if SS
        (progn
          (command "_.layer" "lo" "*" "");图层全锁
          (repeat (setq i (sslength SS))
              (setq ent (ssname SS (setq i (1- i)))
                    ObjLay (cdr (assoc 8 (entget ent)))
              )
              (command "_.layer" "u" ObjLay "")
          )
          (K:LangTips Nil "已锁定除所选对象所在图层外的其它图层" "The layer of the not selected object has been locked")
        )
      )
      (command "redraw")
      (setvar "cmdecho" OLD_CMD)
    (vla-endundomark CurDoc);结束编组
    (princ)
  )

  ;其它常用
  (defun C:HFTC ()(command ".LAYERP" )(princ));恢复上一个图层状态
  (defun C:XZLS ()(command ".SELECTSIMILAR" )(princ));选择类似对象
;按比例插入文字
  ;Global:AllDimSca
  (defun C:TT ( / CurDoc OLD_CMD UcsFlag TmpPT)
    (setq CurDoc (vla-get-activedocument (vlax-get-acad-object)))
    (setq OLD_CMD (getvar "cmdecho"))
    (defun *error* (x)  ;出错函数
      (if OLD_CMD (setvar "cmdecho" OLD_CMD)) ;参数恢复
      (vla-endundomark CurDoc);错误时结束编组
    )
    (while (eq 8 (logand 8 (getvar 'undoctl))) 
        (vla-endundomark CurDoc)
    );关闭以前的编组
    (vla-startundomark CurDoc);记录编组
      (setvar "cmdecho" 0)
      (if (not UcsFlag) (setq UcsFlag T));默认跟随UCS
      (setq Global:AllDimSca
          (if (and (not Global:AllDimSca)  (equal (getvar "DIMSCALE") 1.0 1e-6))
              (setvar "DIMSCALE" 50)
              (getvar "DIMSCALE")
          )
      );默认标注比例
      (setq Global:AllDimSca 
              (if (and (eq (getvar "TILEMODE") 0)(eq (getvar "CVPORT") 1));布局空间
                  1 
                  Global:AllDimSca
              )
      )
      (while ;get*
        (progn 
          (initget (+ 2 4) "H S") ;非零非负关键词
          (setq TmpPT (getpoint (strcat "\n→请指定文字插入点["
                                  (if UcsFlag "跟随坐标(H)" "始终水平(H)")
                                  "/比例(S)_" (rtos Global:AllDimSca 2 1) "]")))
          (cond 
            ((and TmpPT (eq (type TmpPT) 'LIST));指定了点
              (regapp "kucha");为扩展数据注册程序名
              (entmake
                (list 
                    (cons 0 "TEXT")
                    ;(cons 62 256);随层
                    (cons 10 (trans TmpPT 1 0))
                    (cons 11 (trans TmpPT 1 0))
                    
                    (cons 72 1);水平居中
                    (cons 73 2);垂直居中
                    (cons 1 (getvar "CLAYER"));标注图层名
                    (cons 40 (* Global:AllDimSca 3.0));字高
                    (cons 50 
                      (if UcsFlag
                          (angle '(0 0 0)  (trans (getvar 'UCSXDIR) 0 (trans '(0 0 1) 1 0 T)));跟随UCS
                          (- (* 2 pi) (getvar "viewtwist"));始终水平
                      )
                    )
                    (list -3 
                        (list "kucha"
                            (cons 1000 (getenv "USERNAME"));人员
                            (cons 1000 (menucmd "M=$(edtime,$(getvar,date),YYYY/MO/DD)"));时间
                        )
                    )
                )
              );单行提示文字
              T ;继续循环
            )
            ((and (eq (type TmpPT) 'STR)(eq (strcase TmpPT) "H"));字母H
              (setq UcsFlag (not UcsFlag))
              T ;继续循环
            )
            ((and (eq (type TmpPT) 'STR)(eq (strcase TmpPT) "S"));字母S
              (progn
                (initget (+ 2 4));非零非负值
                (setq Global:AllDimSca (cond 
                            ((getreal (strcat "\n→请输入标注比例：<" (rtos Global:AllDimSca 2 2) ">")))
                            (Global:AllDimSca)
                          )
                )
              )
              (setvar "DIMSCALE" Global:AllDimSca) ;CAD标注比例因子
              T ;继续循环
            )
            (T Nil );退出循环
          )
        )
      )
      (setvar "cmdecho" OLD_CMD)
    (vla-endundomark CurDoc);结束编组
    (princ)
  )

;---------------------------------=={图层命令附加}==----------------------------------------;;
	(defun c:1 ()(c:GBTC));关闭图层-附加另一个命令
	(defun c:2 ()(c:TCQK));图层全开-附加另一个命令
	(defun c:3 ()(c:SDTC));锁定图层-附加另一个命令
	(defun c:4 ()(c:JSTC));解锁图层-附加另一个命令

	(defun c:5 ()(c:GBQT));关闭其它-附加另一个命令
	(defun c:6 ()(c:SDQT));锁定其它-附加另一个命令
	(defun c:7 ()(c:HFTC));恢复图层-附加另一个命令

	(defun c:8 ()(c:ZWDQ));置为当前-附加另一个命令
	(defun c:9 ()(c:YZDQ));移至当前-附加另一个命令
	(defun c:0 ()(c:XZLS));选择类似-附加另一个命令

;---------------------------------=={图层命令附加}==----------------------------------------;;

;-------
(if (not (getenv "K\\ToolsIsExit"))
    (princ "\n——★★★ 图层管理Kucha开发，调用命令：0~9 ★★★——\n")
)(princ)