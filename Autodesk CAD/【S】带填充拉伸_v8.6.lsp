(if (null vlax-dump-object) (vl-load-com));将Visual LISP扩展功能加载到 AutoLISP

;Global:STRMvTyp 1动态基点, 2静态位移(支持跨文件)
;Global:STRDIMSC 标注比例/视口比例
;Global:STRModel 是否改变值？
;Global:STRBsePT 默认基点是原点
;Global:STRMvDst 默认位移距离


(defun C:S ( / CurDoc *Old_SysVar* HBLay SS e0 XX HEnLst HBLst BoxLst1 BoxLst2 TmpSS SSRE 
              K:DeleteLay STR:SSRedo4Redit STR:GetSSUCSBox STR:STRETCH4SS
              ;K:SS->EntLst K:EntLst->SS K:SS->Union K:GetNewSS
            )
    (setq CurDoc (vla-get-ActiveDOCument (vlax-get-acad-object)))
    (defun *error*(msg) 
        (if HBLst (foreach XX HBLst (vla-Delete (vlax-ename->vla-object XX))));删除产生的填充边界
        (if HEnLst (command-S "move" (K:EntLst->SS HEnLst) "" "" ""));测试解决关联错误
        (if *Old_SysVar* (foreach xx *Old_SysVar* (apply 'setvar xx)));参数恢复
        (K:DeleteLay HBLay);新建OR删除图层
        (princ "\n——★★★ 拉伸程序退出！ ★★★——\n")
        (vla-endundomark CurDoc) ;错误时结束编组
    )	
    (progn ;基础函数1
        ;选择集转图元表@LeeMac
        (defun K:SS->EntLst (SS / i EntLst) 
            (if SS 
            (repeat (setq i (sslength SS)) 
                (setq EntLst (cons (ssname SS (setq i (1- i))) EntLst))
            )
            )
        )
        ;图元表转选择集@Kucha
        (defun K:EntLst->SS (EntLst / SS XX)
            (setq SS (ssadd));新建选择集
            (foreach XX EntLst (ssadd XX SS));加入选择集
            SS
        )
        ;选择集并集@LeeMac
        (defun K:SS->Union (SS1 SS2 / i) 
            (cond 
                ((null SS1) SS2)
                ((null SS2) SS1)
                ((< (sslength SS1) (sslength SS2))
                (repeat (setq i (sslength SS1)) 
                    (if (not (ssmemb (setq en (ssname SS1 (setq i (1- i)))) SS2))
                        (setq SS2 (ssadd en SS2))
                    )
                )
                SS2
                )
                (T
                (repeat (setq i (sslength SS2)) 
                    (if (not (ssmemb (setq en (ssname SS2 (setq i (1- i)))) SS1))
                        (setq SS1 (ssadd en SS1))
                    )
                )
                SS1
                )
            )
        )
        ;选择集交集@kkq0305
        (defun K:SS->Inters (BseSS TgtSS / en i) 
            (setq i 0)
            (while (setq en (ssname BseSS i)) 
                (or 
                    (ssmemb en TgtSS)
                    (not (ssdel en BseSS))
                    (setq i (1- i))
                )
                (setq i (1+ i))
            )
            BseSS
        )
        ;收集e0之后生成的实体并返回选择集@ET
        (defun K:GetNewSS (en / TmpSS) 
            (if (not en) (setq en (entnext)))
            (setq TmpSS (ssadd))
            (while (setq en (entnext en)) 
              (if 
                (not 
                  (member 
                    (cdr (assoc 0 (entget en)))
                    '("ATTRIB" "VERTEX" "SEQEND")
                  )
                )
                (ssadd en TmpSS)
              )
            )
            (if (zerop (sslength TmpSS)) 
              (setq TmpSS nil)
            )
            TmpSS
        )

        ;新建OR删除图层
        (defun K:DeleteLay (LayNam / LayObj SS i obj) 
            (if (not (tblsearch "LAYER" LayNam));如果图层不存在则新建
                (entmake 
                    (list 
                    (cons 0 "LAYER")
                    (cons 100 "AcDbSymbolTableRecord")
                    (cons 100 "AcDbLayerTableRecord")
                    (cons 70 0) ;层可见性
                    (cons 2 LayNam) ;图层名称
                    (cons 62 1) ;图层颜色
                    (cons 290 0) ;是否打印(0不打印，1打印)
                    )
                );entmake
                (progn
                    (if (eq (getvar "Clayer") LayNam) (setvar "Clayer" "0"));避免边界线图层占用
                    (setq LayObj (vlax-ename->vla-object (tblobjname "LAYER" LayNam)))
                    (vla-put-layeron LayObj :vlax-true) ;打开
                    (vla-put-lock LayObj :vlax-false) ;解锁
                    (vla-put-freeze LayObj :vlax-false) ;解冻

                    (if (setq SS (ssget "X" (list (cons 8 LayNam))));清空图层
                        (repeat (setq i (sslength SS)) 
                        (setq obj (vlax-ename->vla-object (ssname SS (setq i (1- i)))))
                        (vla-Delete obj)
                        )  
                    )
                    ;(vl-catch-all-apply 'vla-delete (list LayObj)) ;删除图层
                ) 
            )
        )
    )
    (progn ;基础函数2
        ;测试重新获取选择集,避免外部参照出错
        (defun STR:SSRedo4Redit (SS / AcProNam AcRefDia XX)
            (setq AcProNam (vla-get-ActiveProfile (vla-get-profiles (vla-get-preferences (vlax-get-Acad-Object)))));当前配置名称
            (setq AcRefDia (strcat "HKEY_CURRENT_USER\\" (vlax-product-key) "\\Profiles\\" AcProNam "\\Dialogs\\RefeditDialog"));当前配置的参照设置
            (if (vl-some '(lambda (XX) (eq "HATCH" (Cdr (Assoc 0 (Entget XX))))) (K:SS->EntLst SS));包含填充
                (if 
                    (and
                        (not (null (getvar "RefEditName")));在位编辑ing
                        (eq 1 (vl-registry-read AcRefDia "LockObjects"));获取参照锁定的值:1打勾,0不打勾
                    )
                    (progn
                        ;https://help.autodesk.com/view/ACD/2023/ENU/?guid=GUID-FD66291F-A997-4D0A-B84C-07C9B8EFB150
                        (command "move" SS "" "" "");如果您尝试编辑锁定的对象，它们将从选择集中过滤掉
                        (ssget "P");重新获取选择集
                    )
                    SS
                )
                SS
            )
        )
        ;获取选择集数据,方便后面生成填充边界后重新选择对象
        (defun STR:GetSSUCSBox (SS / XX X Tmp Lst14 Lst23 LstPid LstWC)
            (foreach XX (ssnamex SS)
                (cond
                    ((member (car XX) '(0 1 4));其它,点选,栏选
                        (setq Lst14 (cons (cadr XX) Lst14))
                    )
                    ((member (car XX) '(2 3));框选,叉选对应的多边形id
                        (if 
                            (and
                                (setq Tmp (cons (Last XX) (car XX)))
                                (not (member Tmp Lst23))
                            )
                            (setq Lst23 (cons Tmp Lst23))
                        )
                    )
                    ((< (car XX) 0) ;框选,叉选多边形id及WCS坐标
                    (setq LstPid (cons XX LstPid))
                    )
                )
            )
            (if (and Lst23 LstPid)
                (foreach XX LstPid
                    (setq LstWC
                        (cons
                            (cons
                                (Cdr (Assoc (car XX) Lst23))
                                (mapcar 
                                    '(lambda (x) (trans (list (car x) (cadr x) 0.0) 0 1));WCS转UCS,因为ssget使用的是UCS
                                    (mapcar 'cadr (cdr xx));多边形WCS点表
                                )
                            )
                            LstWC 
                        )
                    )
                )
            )
            (if Lst14 
                (append (list (cons 14 Lst14)) LstWC)
                LstWC
            )
        )
        ;|拉伸程序改写，支持空格默认@Kucha
            Global:STRMvTyp 1动态基点, 2静态位移
            Global:STRMvDst 默认位移距离
            Global:STRBsePT 默认位移量
        |;
        (defun STR:STRETCH4SS (SS / STR:SetGetData STR:GetCurDIMSC *MkVarLst* NoZero FstPT TmpDst TgtDst a b XX)
            ;(setq SS (ssget))
            (progn ;基础函数
                    ;根据分隔符拆分字符串@LeeMac
                    (defun K:STR->Lst (STR Del / len Lst pos) 
                    (setq len (1+ (strlen Del)))
                    (while (setq pos (vl-string-search Del STR)) 
                        (setq Lst (cons (substr STR 1 pos) Lst)
                            STR (substr STR (+ pos len))
                        )
                    )
                    (reverse (cons STR Lst))
                    )
                    ;使用分隔符串联字符串@LeeMac
                    (defun K:Lst->STR (Lst Del / STR) 
                    (setq STR (car Lst))
                    (foreach itm (cdr Lst) (setq STR (strcat STR Del itm)))
                    STR
                    )
                    ;获取或更新变量(系统+全局+黑板),不存在时更新为默认值(系统变量记录的全局变量值使用@@分隔)
                    (defun STR:SetGetData (RecDATA SysNam VarLst  / XX SysLst a b) 
                        (if 
                            (vl-every 
                            '(lambda (XX) 
                                (and 
                                    (eval (read (car XX)));全局变量存在
                                    (vl-bb-ref (read (car XX)));黑板空间存在同名变量
                                    (eq (type (eval (read (car XX)))) 'STR);全局变量的值都为STR
                                    (eq (type (vl-bb-ref (read (car XX)))) 'STR);全局变量的值都为STR
                                )
                            )
                            VarLst
                            );变量存在且类型都为STR
                            (if RecDATA
                                (progn
                                    (setq SysLst (mapcar '(lambda (XX) (eval (read (car XX)))) VarLst));取全局
                                    (setenv SysNam (K:Lst->STR SysLst "@@")) ;更新系统
                                    (mapcar '(lambda (a b) (vl-bb-set (read (car a)) b)) VarLst SysLst) ;更新黑板
                                );用全局更新黑板+系统
                                (progn
                                    (setq SysLst (mapcar '(lambda (XX) (vl-bb-ref (read (car XX)))) VarLst));取黑板
                                    (setenv SysNam (K:Lst->STR SysLst "@@")) ;更新系统
                                    (mapcar '(lambda (a b) (set (read (car a)) b)) VarLst SysLst) ;更新全局
                                );用黑板更新全局+系统
                            )
                            (if 
                                (and
                                    (getenv SysNam) ;系统变量存在
                                    (setq SysLst (K:STR->Lst (getenv SysNam) "@@"));尝试从系统变量中提取全局变量的值
                                    (eq (length SysLst) (length VarLst));值的数量相等
                                )
                                (mapcar '(lambda (a b) 
                                            (set (read (car a)) b);更新全局变量
                                            (vl-bb-set (read (car a)) b);更新黑板空间的变量值
                                        ) 
                                        VarLst 
                                        SysLst
                                )
                                (progn
                                    (setenv SysNam (K:Lst->STR (mapcar 'cadr VarLst) "@@")) ;更新系统变量为默认值
                                    (mapcar '(lambda (XX) (set (read (car XX)) (cadr XX))) VarLst);更新全局变量为默认
                                    (mapcar '(lambda (XX) (vl-bb-set (read (car XX)) (eval (read (car XX))))) VarLst);更新黑板空间变量为默认
                                )
                            )
                        )(princ)
                    )
                    ;获取拉伸的换算比例
                    (defun STR:GetCurDIMSC (STRDIMSC / TmpVSC)
                        (if (and (eq (getvar "TILEMODE") 0)(> (getvar "CVPORT") 1));活动视口
                            (setq TmpVSC (/ 1 (vla-get-CustomScale (vla-get-ActivePViewport (vla-get-activedocument (vlax-get-acad-object))))))
                            (if (not STRDIMSC)(setq TmpVSC 1.0)(setq TmpVSC STRDIMSC))
                        )
                        ;(if (not TmpVSC)(setq TmpVSC 1.0))
                        ;|
                        (setq Tflag (equal (type (eval (read "TGetPScale"))) 'EXRXSUBR))
                        (cond 
                            ((and (eq (getvar "TILEMODE") 0)(> (getvar "CVPORT") 1));活动视口
                            ;取视口比例并且设置值  
                            (setq TmpVSC (/ 1 (vla-get-CustomScale (vla-get-ActivePViewport (vla-get-activedocument (vlax-get-acad-object))))))
                            )
                            ((eq (getvar "TILEMODE") 1);模型空间
                                ;取天正或CAD标注比例
                                (setq TmpVSC (if Tflag (TGetPScale) (getvar "DIMSCALE")))
                            )
                            ((and (eq (getvar "TILEMODE") 0)(eq (getvar "CVPORT") 1));布局空间
                                ;取天正或CAD标注比例
                                (setq TmpVSC (if Tflag (getvar "HPSCALE") (getvar "DIMSCALE")))
                            )
                            (t (setq TmpVSC 1.0))
                        );获取比例
                        |;
                        (if
                            (or
                                (and 
                                (>= TmpVSC 1.0);大于等于1，例如1:1或5：1
                                (/= (distof (rtos TmpVSC 2 2))(distof (rtos TmpVSC 2 0)));非整数且尾数大于0.01
                                )
                                (and
                                (< TmpVSC 1.0);小于1，例如1:20
                                (/= (distof (rtos TmpVSC 2 2))(distof (rtos TmpVSC 2 0)));非整数且尾数大于0.01
                                )
                            )
                            (princ "\n——★★★ 当前比例可能不是常用值，请检查! ★★★——\n")
                        )(princ)
                        ;(if Tflag (TsetPScale TmpVSC) (setvar "DIMSCALE" TmpVSC));设置比例值
                        TmpVSC
                    )
            )
            (setq *MkVarLst*
                (list 
                    (list "Global:STRMvTyp" "1");1动态基点, 2静态位移
                )
            );参数列表，自行扩写
            (STR:SetGetData Nil "K\\K:STRETCHSys" *MkVarLst*);用黑板更新系统和全局(缺省取默认)

            (setq Global:STRDIMSC (STR:GetCurDIMSC Global:STRDIMSC));标注比例
            (if (not Global:STRModel) (setq Global:STRModel Nil));默认不改变
            (if (not Global:STRBsePT) (setq Global:STRBsePT (list 0.0 0.0 0.0)));默认基点
            (if (not Global:STRMvDst) (setq Global:STRMvDst (Distance (list 0.0 0.0 0.0) Global:STRBsePT)));默认位移距离
            (setq NoZero (not (vl-every '(lambda (a b) (equal a b 0.001)) Global:STRBsePT (list 0.0 0.0 0.0))));位移量不为0.0的标记
            (if (and (eq (getvar "TILEMODE") 0)(> (getvar "CVPORT") 1));活动视口
                (setq Global:STRModel T)
            )        
            
            (if (not (null SS));选择集不为空
                (progn
                    (if NoZero
                        (princ 
                            (strcat 
                            "\n→空格使用上次位移量: 【"
                            "X="
                            (rtos (car Global:STRBsePT) 2 1)
                            ", Y="
                            (rtos (cadr Global:STRBsePT) 2 1)
                            ", Z="
                            (rtos (caddr Global:STRBsePT) 2 1)
                            "】"
                            )
                        )
                    )
                    (while ;get*
                        (progn 
                        (initget "F S M");关键词
                        (setq FstPT 
                                (getpoint 
                                    (strcat 
                                        "\n→请指定起点或 [反向(F)"
                                        "/比例(S)_" (rtos Global:STRDIMSC 2 1)
                                        (if (eq "1" Global:STRMvTyp);1动态基点, 2静态位移
                                            "/动态基点(M)-终点空格容易卡死"
                                            "/静态位移(M)"
                                        )
                                        "]: "
                                    )
                                )
                        )
                        (cond 
                            ((and (eq (type FstPT) 'STR)(eq (strcase FstPT) "F"));字母F
                                (if NoZero
                                    (progn
                                        (setq Global:STRBsePT (mapcar '(lambda (XX) (* -1 XX)) Global:STRBsePT));上次的反向
                                        (command "_.STRETCH" SS "" "non" (list 0.0 0.0 0.0) "non" Global:STRBsePT)
                                        (princ "\n——★★★ 位移反转,对象拉伸完毕！ ★★★——\n")
                                        Nil ;退出循环
                                    )
                                    (progn
                                        (princ "\n——★★★ 上次位移为零,无法反向拉伸！ ★★★——\n")
                                        T ;继续循环
                                    )
                                )
                            )
                            ((and (eq (type FstPT) 'STR)(eq (strcase FstPT) "S"));字母S
                                (if
                                    (progn
                                        (initget (+ 1 2 4));非空非零非负值
                                        (setq Global:STRDIMSC (getreal (strcat "\n→请输入新比例：<" (rtos Global:STRDIMSC 2 1) ">")))
                                    )
                                    (progn
                                        (princ "\n——★★★ 在活动视口中拉伸后，再回到在布局中拉伸时,位移值将除以该比例! ★★★——\n")(princ)
                                        (if (equal (type (eval (read "TGetPScale"))) 'EXRXSUBR)
                                            (TsetPScale Global:STRDIMSC)
                                            (setvar "DIMSCALE" Global:STRDIMSC)
                                        );设置标注比例值
                                    )
                                )
                                T ;继续循环
                            )
                            ((and (eq (type FstPT) 'STR)(eq (strcase FstPT) "M"));字母M
                                (cond
                                    ((eq "1" Global:STRMvTyp)
                                        (setq Global:STRMvTyp "2")
                                        (princ "\n——★★★ 拉伸模式为->> 静态位移 ★★★——\n")
                                    )
                                    ((eq "2" Global:STRMvTyp)
                                        (setq Global:STRMvTyp "1")
                                        (princ "\n——★★★ 拉伸模式为->> 动态基点 ★★★——\n")
                                    )
                                )
                                (STR:SetGetData T "K\\K:STRETCHSys" *MkVarLst*);用全局更新系统和黑板
                                T ;继续循环
                            )
                            ((not FstPT) ;起点空格回车使用上次位移
                                (if NoZero
                                    (progn
                                        (command "_.STRETCH" SS "" "non" (list 0.0 0.0 0.0) "non" Global:STRBsePT)
                                        (princ "\n——★★★ 对象拉伸完毕！ ★★★——\n")
                                        Nil ;退出循环
                                    )
                                    (progn
                                        (princ "\n——★★★ 上次位移为零,无法使用拉伸！ ★★★——\n")
                                        T ;继续循环
                                    )
                                )
                            )
                            ((and FstPT (eq (type FstPT) 'LIST));指定了点
                                (if (eq "1" Global:STRMvTyp);1动态基点, 2静态位移
                                    (progn
                                    (princ "\n→注：指定终点时空格，将以起点的UCS坐标作为位移量,可能会卡死！！！\n");换行
                                    (command "_.STRETCH" SS "" "non" FstPT pause)
                                    (setq Global:STRBsePT (mapcar '- (getvar "lastpoint") FstPT));更新位移
                                    (princ "\n——★★★ 对象拉伸完毕！ ★★★——\n")
                                    )
                                    (progn
                                        (command "_.STRETCH" SS "" FstPT)
                                        (setq TmpDst (getdist FstPT (strcat "\n→请指定终点或输入拉伸距离<" (rtos Global:STRMvDst 2 2) ">: ")))
                                        (if (not TmpDst) 
                                            (setq TgtDst Global:STRMvDst)
                                            (setq TgtDst TmpDst)
                                        )
                                        (command TgtDst)
                                    
                                        (setq Global:STRMvDst TgtDst)
                                        (setq Global:STRBsePT (mapcar '- (getvar "lastpoint") FstPT));更新位移
                                        (princ "\n——★★★ 对象拉伸完毕！ ★★★——\n")
                                    )
                                )
                            Nil ;退出循环
                            )
                            (T
                                (princ "\n——★★★ 拉伸程序退出！ ★★★——\n")
                                Nil ;退出循环
                            )
                        )
                        )
                    )
                )
            )
            (STR:SetGetData T "K\\K:STRETCHSys" *MkVarLst*);用全局更新系统和黑板
            (princ)
        )
    )
    (while (eq 8 (logand 8 (getvar 'undoctl))) 
        (vla-endundomark CurDoc)
    ) ;关闭以前的编组
    (vla-startundomark CurDoc)  
        (setq HBLay "Z-拉伸边界(不要存对象到这里)");设置边界线图层
        (K:DeleteLay HBLay);新建OR删除图层
        ;--------
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
                (list "CLAYER" HBLay) ;图层
                (list "CECOLOR" "250") ;颜色红色
                (list "PICKSTYLE" 0) ;忽略编组选择
                (list "DIMZIN" 0) ;实数不消零
                (list "CMDECHO" 0) ;关闭回显
            )
            )
        );记录参数
        (if (and Global:STRModel (eq (getvar "TILEMODE") 0)(eq (getvar "CVPORT") 1));布局空间
            (progn
                (setq Global:STRModel Nil);清空
                (setq Global:STRBsePT (mapcar '(lambda (XX) (/ XX Global:STRDIMSC)) Global:STRBsePT))
            )
        )
        (if (setq SS (STR:SSRedo4Redit (ssget ":L")))
            (if (not 
                    (setq HEnLst (vl-remove-if-not 
                                '(lambda (XX) (eq "HATCH" (Cdr (Assoc 0 (Entget XX))))) ;只选填充
                                (K:SS->EntLst SS)
                                )
                    )
                );没有填充
                (STR:STRETCH4SS SS);带记忆拉伸
                (progn
                    (progn ;收集产生的填充边界
                        (setq e0 (entlast));记录实体起始点
                        (foreach XX HEnLst
                            (if (eq 0 (Cdr(Assoc 71 (Entget XX))))
                                (progn
                                    (command "_.HATCHEDIT" XX "_DI");解除关联
                                    (command "_.HATCHEDIT" XX "b" "p" "y");创建填充边界
                                )
                            )
                        )
                        (setq HBLst (K:SS->EntLst (K:GetNewSS e0)))
                    )
                    (setq BoxLst1 (vl-remove-if-not '(lambda (XX) (eq 14 (car XX))) (STR:GetSSUCSBox SS)));点选OR栏选OR其它
                    (setq BoxLst2 (vl-remove-if-not '(lambda (XX) (or (eq 2 (car XX)) (eq 3 (car XX)))) (STR:GetSSUCSBox SS)));框选+叉选
                    (progn ;根据选择集UCS选框坐标重新叉选对象
                        (command ".SELECT")
                        (foreach XX BoxLst2
                            (if (eq (car xx) 2)
                                (command "W" "non" (car (cdr xx)) "non" (caddr (cdr xx)))
                                (command "C" "non" (car (cdr xx)) "non" (caddr (cdr xx)))
                            )
                        )
                        (command "")
                        (setq SSRE (ssget "p"))
                    )
                    (cond
                        ((and BoxLst1 BoxLst2)
                            (STR:STRETCH4SS (K:SS->Inters (K:SS->Union SSRE (K:EntLst->SS (cdar BoxLst1))) (K:SS->Union SS (K:EntLst->SS HBLst))));带记忆拉伸
                        )
                        ((and (null BoxLst1) BoxLst2)
                            (STR:STRETCH4SS (K:SS->Inters SSRE (K:SS->Union SS (K:EntLst->SS HBLst))));带记忆拉伸
                        )
                        ((and BoxLst1 (null BoxLst2))
                            (STR:STRETCH4SS (K:EntLst->SS (cdar BoxLst1)));带记忆拉伸
                        )
                    )
                    (if HBLst (foreach XX HBLst (vla-Delete (vlax-ename->vla-object XX))));删除产生的填充边界
                    (if HEnLst (command "move" (K:EntLst->SS HEnLst) "" "" ""));测试解决关联错误
                )
            )
        )
        (command "redraw")
        (if *Old_SysVar* (foreach xx *Old_SysVar* (apply 'setvar xx)));参数恢复
        (K:DeleteLay HBLay);新建OR删除图层
    (vla-endundomark CurDoc)
    (princ)
)

(if (not (getenv "K\\ToolsIsExit"))
    (princ "\n——★★★ 填充拉伸由Kucha开发, 调用命令: S ★★★——")
)(princ)
