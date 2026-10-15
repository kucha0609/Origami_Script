;文本内容刷由阿甘开发,Kucha优化
;命令：FA 
;Global:UpText 上标文字
;Global:DwText 下标文字
;Global:BrushTgt 上下标/上标/下标
;Global:EditMode 替换/加前/加后/截取
;Global:GetSTRF 取的截取范围(前)
;Global:GetSTRB 取的截取范围(后)
;Global:SetSTRF 刷的截取范围(前)
;Global:SetSTRB 刷的截取范围(后)

(if (null vlax-dump-object) (vl-load-com));;将Visual LISP扩展功能加载到AutoLISP


;文字刷子程序
(defun K:TextBrush4FA (en BrushTgt EditMode SetSTRF SetSTRB UpText DwText 
                        / obj EnType OriUpT TmpUpT TmpDwT FstLst BGLst qm hm ObjNam TmpMea TmpOve TmpDEF
                      ) 
  (setq obj     (vlax-ename->vla-object en)
        EnType  (cdr (assoc 0 (entget en)))
        OriUpT  UpText ;做法专用(做法标注+天正多行->做法标注)
  )
  (if (vl-string-search "\r\n" UpText) 
      (setq UpText (apply 'strcat (K:STR->Lst UpText "\r\n")))
  );如果上标含做法标注格式将去除

  (if (eq BrushTgt "3") ;仅刷下标
    (cond
      ((eq EnType "TCH_ARROW")
        (setq TmpDwT (K:GetProp obj 'Text2))
        (if (member (K:GetProp obj 'Alignment) (list "在线端" "在箭头"))
          (K:PutProp obj 'Text2 "") ;下标
          (K:PutProp obj 'Text2 
              (cond
                ((eq "1" EditMode) UpText)
                ((eq "2" EditMode) (strcat UpText TmpDwT))
                ((eq "3" EditMode) (strcat TmpDwT UpText))
                ((eq "4" EditMode) (K:GetTgtSTR T TmpDwT (atoi SetSTRF) (atoi SetSTRB) UpText))
              )
          ) ;下标
        )
      );天正箭头引注
      ((eq EnType "TCH_MULTILEADER")
        (setq TmpDwT (K:GetProp obj 'DownText))
        (K:PutProp obj 'DownText 
          (cond
            ((eq "1" EditMode) UpText)
            ((eq "2" EditMode) (strcat UpText TmpDwT))
            ((eq "3" EditMode) (strcat TmpDwT UpText))
            ((eq "4" EditMode) (K:GetTgtSTR T TmpDwT (atoi SetSTRF) (atoi SetSTRB) UpText))
          )
        ) ;下标
      );天正引出标注
      ((eq EnType "TCH_ELEVATION")
          (setq BGLst (K:RtnBGLst obj)
                qm (car BGLst)
                hm (cadr BGLst)
          )
          (K:PutProp obj 'Text 
            (cond
              ((eq "1" EditMode) 
                  (if (or (vl-string-search "$" qm) (eq UpText ""));多层标高或为空时不添加下标
                      qm
                      (strcat qm "&" UpText) 
                  )
              )
              ((eq "2" EditMode) (strcat qm "&" UpText hm))
              ((eq "3" EditMode) (strcat qm "&" hm UpText))
              ((eq "4" EditMode) (strcat qm "&" (K:GetTgtSTR T hm (atoi SetSTRF) (atoi SetSTRB) Nil) UpText))
            )
          )
      );天正标高
      ((eq EnType "TCH_COMPOSING")
        (setq TmpUpT (K:GetProp obj 'Text))
        (K:PutProp obj 'Text 
          (cond
            ((eq "1" EditMode) OriUpT)
            ((eq "2" EditMode) (strcat OriUpT "\r\n" TmpUpT))
            ((eq "3" EditMode) (strcat TmpUpT "\r\n" OriUpT))
            ((eq "4" EditMode) (setq TmpSTR (K:GetTgtSTR Nil TmpUpt (atoi SetSTRF) (atoi SetSTRB) OriUpT)))
          )
        )
      );天正做法标注
      (t 
        (princ "\n——★★★ 请选择天正箭头引注、引出标注、单层标高或做法标注! > ★★★——\n")
      )
    )
    (cond
      ((member EnType '("DIMENSION" "ARC_DIMENSION" "LARGE_RADIAL_DIMENSION"))
        (setq ObjNam (K:GetProp obj 'ObjectName);对象名
              TmpMea (K:GetProp obj 'Measurement);测量
              TmpOve (K:GetProp obj 'TextOverride);文本覆盖
        )
        (setq TmpUpt 
            (if (/= "" TmpOve)
                TmpOve
                (cond
                    ((eq ObjNam "AcDbDiametricDimension");直径标注
                      (strcat "%%C" (rtos TmpMea))
                    )
                    ((eq ObjNam "AcDbRadialDimension");半径标注
                      (strcat "R" (rtos TmpMea))
                    )
                    ((member ObjNam (list "AcDb2LineAngularDimension" "AcDb3PointAngularDimension"));角度标注
                      (strcat (rtos (* 180 (/ TmpMea pi))) "°")
                    )
                    (T (rtos TmpMea))
                )
            );避免为空
        )
        (K:PutProp obj 'TextOverride 
          (cond
            ((eq "1" EditMode) UpText)
            ((eq "2" EditMode) (strcat UpText TmpUpt))
            ((eq "3" EditMode) (strcat TmpUpt UpText))
            ((eq "4" EditMode) (K:GetTgtSTR T TmpUpt (atoi SetSTRF) (atoi SetSTRB) UpText))
          )
        )
      );CAD标注：CAD半径+CAD直径+线性标注+对齐标注+角度标注+坐标标注+弧长标注+折弯标注
      ((member EnType '("TEXT" "MTEXT" "MULTILEADER" "ATTRIB"))
        (setq TmpUpt (K:GetProp obj 'TextString))
        (K:PutProp obj 'TextString 
          (cond
            ((eq "1" EditMode) UpText)
            ((eq "2" EditMode) (strcat UpText TmpUpt ))
            ((eq "3" EditMode) (strcat TmpUpt UpText))
            ((eq "4" EditMode) (K:GetTgtSTR T TmpUpt (atoi SetSTRF) (atoi SetSTRB) UpText))
          )
        )

      );CAD单行+CAD多行+CAD引线+CAD属性字
      ((eq EnType "ATTDEF")
        (setq TmpUpt (K:GetProp obj 'TagString))
        (setq TmpDEF (K:GetTgtSTR T TmpUpt (atoi SetSTRF) (atoi SetSTRB) UpText))
        (K:PutProp obj 'TagString 
            (cond
              ((eq "1" EditMode) UpText)
              ((eq "2" EditMode) (strcat UpText TmpUpt))
              ((eq "3" EditMode) (strcat TmpUpt UpText))
              ((eq "4" EditMode) 
                  (if (/= "" TmpDEF) TmpDEF TmpUpt)
              );属性定义不能为空
            )
        ) ;改标记
        (if (= "" TmpDEF)
            (princ "\n——★★★ 属性定义不能为空 ★★★——\n")
        )
      );如果是属性定义, 则取"标记"
      ((member EnType '("TCH_TEXT" "TCH_NORTHTHUMB"))
        (setq TmpUpT (K:GetProp obj 'Text))
        (K:PutProp obj 'Text 
          (cond
            ((eq "1" EditMode) UpText)
            ((eq "2" EditMode) (strcat UpText TmpUpT ))
            ((eq "3" EditMode) (strcat TmpUpT UpText))
            ((eq "4" EditMode) (K:GetTgtSTR T TmpUpt (atoi SetSTRF) (atoi SetSTRB) UpText))
          )
        )
      );天正单行+天正指北针
      ((eq EnType "TCH_ELEVATION")
        (setq TmpUpT (K:GetProp obj 'Text)
              BGLst (K:RtnBGLst obj)
              qm (car BGLst)
              hm (cadr BGLst)
        )
        (if (eq BrushTgt "2");仅刷上标
            (if (vl-string-search "$" qm);多层标高时
              (princ "\n——★★★ 存在多层标高! > ★★★——\n")
              (if (eq hm "");不存在下标时
                  (K:PutProp obj 'Text 
                    (cond
                      ((eq "1" EditMode) UpText)
                      ((eq "2" EditMode) (strcat UpText qm))
                      ((eq "3" EditMode) (strcat qm UpText))
                      ((eq "4" EditMode) (K:GetTgtSTR T qm (atoi SetSTRF) (atoi SetSTRB) UpText))
                    )
                  )
                  (K:PutProp obj 'Text 
                    (cond
                      ((eq "1" EditMode) (if (eq UpText "") hm (strcat UpText "&" hm)))
                      ((eq "2" EditMode) (strcat UpText qm "&" hm))
                      ((eq "3" EditMode) (strcat qm UpText "&" hm))
                      ((eq "4" EditMode) (strcat (K:GetTgtSTR T qm (atoi SetSTRF) (atoi SetSTRB) UpText) "&" hm))
                    )
                  )
              )

            )
            (K:PutProp obj 'Text 
              (cond
                  ((eq "1" EditMode) UpText)
                  ((eq "2" EditMode) (strcat UpText TmpUpT))
                  ((eq "3" EditMode) (strcat TmpUpT UpText))
                  ((eq "4" EditMode) (K:GetTgtSTR T TmpUpt (atoi SetSTRF) (atoi SetSTRB) UpText))
              )
            );上下标
        )
      );天正标高
      ((eq EnType "TCH_DRAWINGNAME")
        (setq TmpUpT (K:GetProp obj 'NameText))
        (K:PutProp obj 'NameText 
          (cond
            ((eq "1" EditMode) UpText)
            ((eq "2" EditMode) (strcat UpText TmpUpT ))
            ((eq "3" EditMode) (strcat TmpUpT UpText))
            ((eq "4" EditMode) (K:GetTgtSTR T TmpUpt (atoi SetSTRF) (atoi SetSTRB) UpText))
          )
        )
      );天正图名
      ((eq EnType "TCH_DRAWINGINDEX")
        (setq TmpUpT (K:GetProp obj 'IndexLabel))
        (K:PutProp obj 'IndexLabel 
          (cond
            ((eq "1" EditMode) UpText)
            ((eq "2" EditMode) (strcat UpText TmpUpT ))
            ((eq "3" EditMode) (strcat TmpUpT UpText))
            ((eq "4" EditMode) (K:GetTgtSTR T TmpUpt (atoi SetSTRF) (atoi SetSTRB) UpText))
          )
        )
      );天正索引图名
      ((eq EnType "TCH_SYMB_SECTION")
        (setq TmpUpT (K:GetProp obj 'Text))
        (K:PutProp obj 'Text 
          (cond
            ((eq "1" EditMode) UpText)
            ((eq "2" EditMode) (strcat UpText TmpUpT ))
            ((eq "3" EditMode) (strcat TmpUpT UpText))
            ((eq "4" EditMode) (K:GetTgtSTR T TmpUpt (atoi SetSTRF) (atoi SetSTRB) UpText))
          )
        )
      );天正剖面剖切
      ((eq EnType "TCH_ARROW")
        (setq TmpUpT (K:GetProp obj 'Text)
              TmpDwT (K:GetProp obj 'Text2)
        )
        (K:PutProp obj 'Text 
          (cond
            ((eq "1" EditMode) UpText)
            ((eq "2" EditMode) (strcat UpText TmpUpT))
            ((eq "3" EditMode) (strcat TmpUpT UpText))
            ((eq "4" EditMode) (K:GetTgtSTR T TmpUpt (atoi SetSTRF) (atoi SetSTRB) UpText))
          )
        );上标
        (if (eq BrushTgt "1");刷上下标中的下标
          (if 
            (or
              (eq "在线端" (K:GetProp obj 'Alignment))
              (eq "在箭头" (K:GetProp obj 'Alignment))
            )
            (K:PutProp obj 'Text2 "") ;下标
            (K:PutProp obj 'Text2 
              (cond
                ((eq "1" EditMode) DwText)
                ((eq "2" EditMode) (strcat DwText TmpDwT))
                ((eq "3" EditMode) (strcat TmpDwT DwText))
                ((eq "4" EditMode) (K:GetTgtSTR T TmpDwT (atoi SetSTRF) (atoi SetSTRB) DwText))
              ) 
            ) ;下标
          )
        )
      );天正箭头引注
      ((eq EnType "TCH_MULTILEADER")
        (setq TmpUpT (K:GetProp obj 'UpText)
              TmpDwT (K:GetProp obj 'DownText)
        )
        (K:PutProp obj 'UpText 
          (cond
            ((eq "1" EditMode) UpText)
            ((eq "2" EditMode) (strcat UpText TmpUpT ))
            ((eq "3" EditMode) (strcat TmpUpT UpText))
            ((eq "4" EditMode) (K:GetTgtSTR T TmpUpt (atoi SetSTRF) (atoi SetSTRB) UpText))
          )
        ) ;上标
        (if (eq BrushTgt "1");刷上下标中的下标
          (K:PutProp obj 'DownText 
            (cond
              ((eq "1" EditMode) DwText)
              ((eq "2" EditMode) (strcat DwText TmpDwT ))
              ((eq "3" EditMode) (strcat TmpDwT DwText))
              ((eq "4" EditMode) (K:GetTgtSTR T TmpDwT (atoi SetSTRF) (atoi SetSTRB) DwText))
            )
          ) ;下标
        )
      );天正引出标注
      ((eq EnType "TCH_COMPOSING")
        (setq TmpUpT (K:GetProp obj 'Text))
        (if (and (eq BrushTgt "1")(/= DwText "")) (setq OriUpT (strcat OriUpT "\r\n" DwText)));上下标的时候取把下标给上
        
        (K:PutProp obj 'Text 
          (cond
            ((eq "1" EditMode) OriUpT)
            ((eq "2" EditMode) (strcat OriUpT "\r\n" TmpUpT))
            ((eq "3" EditMode) (strcat TmpUpT "\r\n" OriUpT))
            ((eq "4" EditMode) (K:GetTgtSTR Nil TmpUpt (atoi SetSTRF) (atoi SetSTRB) OriUpT))
          )
        )
      );天正做法标注
      (t 
        (princ "\n——★★★ 不可刷: 不支持的对象类型!  ★★★——\n")
      )
    )
  )
  (entupd en);刷新
)

(defun c:FA (/ K:SetGetUpdVar CurDoc *Old_SysVar* Global:VarLst1 Global:VarLst2  
             Code TmpLst OriEn SS SSData i TgtPT en TgtPTen obj ent EnType TmpTips 
             ObjNam StyRud TmpMea TmpOve TmpUpText BGLst STRLst FstLst
             Count NoGetSTR YesUPSTR 
            )   
  (setq CurDoc (vla-get-activedocument (vlax-get-acad-object)))
  (progn ;基础函数
      (defun *error* (x) ;出错函数
        (if OriEn (redraw OriEn 4));取消亮显
        (K:SetGetUpdVar Nil "FAWZSys1" Global:VarLst1);更新变量(若无则设置为默认值)
        (K:SetGetUpdVar Nil "FAWZSys2" Global:VarLst2);更新变量(若无则设置为默认值)
        (foreach xx *Old_SysVar* (apply 'setvar xx));参数恢复
        (vla-endundomark CurDoc) ;结束编组
      )
      ;获取或更新变量(全局+系统)，将所有参数记录到一个系统变量。
      ;参数之间使用分号@@分隔，类型必须为字符串。Flag为是T时强制更新为默认值
      (defun K:SetGetUpdVar (Flag SysNam VarLst / XX GlbLst SysLst a b) 
        ;(K:SetGetUpdVar SysNam (list (list "Key名" "变量名" "默认值")...))
          (progn  ;基础函数
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
          )
          (setq SysNam (strcat "K\\" SysNam));系统变量名
          (setq VarLst 
              (mapcar 
                '(lambda (XX) (list (nth 0 XX) (strcat "Global:" (nth 1 XX)) (nth 2 XX)))
                VarLst
              )
          );全局变量名补全
          (mapcar 
            '(lambda (XX) 
              (if (and (nth 0 XX)(get_tile (nth 0 XX)))
                  (set (read (nth 1 XX)) (get_tile (nth 0 XX)))
              )
            )
            VarLst
          );获取DCL对应Key的值,更新对应的全局变量
        
          (if Flag ;强制更新变量值
              (progn
                  (setenv SysNam (K:Lst->STR (mapcar 'caddr VarLst) "@@")) ;更新系统变量为默认值
                  (mapcar '(lambda (XX) (set (read (nth 1 XX)) (nth 2 XX))) VarLst);更新全局变量为默认 
              )
              (if 
                  (vl-every 
                    '(lambda (XX) 
                      (and 
                        (eval (read (nth 1 XX)))
                        (eq (type (eval (read (nth 1 XX)))) 'STR)
                      )
                    )
                    VarLst
                  );全局变量都存在且都为STR
                  (progn
                      (mapcar '(lambda (xx) (setq GlbLst (cons (eval (read (nth 1 XX))) GlbLst ))) VarLst);收集全局变量
                      (setenv SysNam (K:Lst->STR (reverse GlbLst) "@@")) ;更新系统变量
                  )
                  (if 
                    (and
                        (getenv SysNam) ;系统变量存在
                        (setq SysLst (K:STR->Lst (getenv SysNam) "@@"));尝试从系统变量中提取全局变量
                        (eq (length SysLst) (length VarLst));数量相等
                    )
                    (progn
                        (mapcar '(lambda (a b) (set (read (nth 1 a)) b)) VarLst SysLst);更新全局变量
                    )
                    (progn
                        (setenv SysNam (K:Lst->STR (mapcar 'caddr VarLst) "@@")) ;更新系统变量为默认值
                        (mapcar '(lambda (XX) (set (read (nth 1 XX)) (nth 2 XX))) VarLst);更新全局变量为默认
                    )
                  )
              )
          )
          (princ)
      )
  )

  (while (eq 8 (logand 8 (getvar 'undoctl))) 
      (vla-endundomark CurDoc)
  );关闭以前的编组
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
              (list "DIMZIN" 12) ;删除尾零和前导零
            )
          )
      );记录参数

      (if (getenv "K\\FAGlobal-UpText")
        (setq Global:UpText (getenv "K\\FAGlobal-UpText"))
        (setenv "K\\FAGlobal-UpText" (setq Global:UpText ""))
      )
      (if (getenv "K\\FAGlobal-DwText")
          (setq Global:DwText (getenv "K\\FAGlobal-DwText"))
          (setenv "K\\FAGlobal-DwText" (setq Global:DwText ""))
      )
      
      (setq Global:VarLst1
          (list 
            (list "Key1" "BrushTgt" "1");1刷上下标,2仅刷上标,3仅刷下标
            (list "Key2" "EditMode" "1");1替换,2加前,3加后,4截取
          )
      );参数列表，自行扩写
      (setq Global:VarLst2
          (list 
            (list "Key3" "GetSTRF" "3");取的截取范围(前)
            (list "Key4" "GetSTRB" "0");取的截取范围(后)
            (list "Key5" "SetSTRF" "3");刷的截取范围(前)
            (list "Key6" "SetSTRB" "0");刷的截取范围(后)
          )
      );参数列表，自行扩写
      (K:SetGetUpdVar Nil "FAWZSys1" Global:VarLst1);更新变量(若无则设置为默认值)
      (K:SetGetUpdVar Nil "FAWZSys2" Global:VarLst2);更新变量(若无则设置为默认值)
      
      (if (not (eq Global:UpText ""))  ;如果上标存在
        (princ (strcat "\n——★★★ 文字内容默认值为 <" Global:UpText "> ★★★——\n"))
      )
      (setq YesUPSTR T);是否执行后续的刷字程序
    )
    (while 
      (progn
        ;"A R G Z D F B 1 2"
        (if (eq Global:EditMode "4") 
            (setq TmpTips (strcat  "/取(1)_" Global:GetSTRF "+" Global:GetSTRB "/刷(2)_" Global:SetSTRF "+" Global:SetSTRB) )
            (setq TmpTips "")
        )
        (princ 
          (strcat 
            "\n→请选择源文字<空格默认>[清空(A)/重置(R)/下给上(G)/做法倒置(Z)"
            (cond
              ((eq Global:BrushTgt "1") "/刷上下标(D)" )
              ((eq Global:BrushTgt "2") "/仅刷上标(D)" )
              ((eq Global:BrushTgt "3") "/仅刷下标(D)" )
            )
            (cond
              ((eq Global:EditMode "1") "/替换(F)/(B)" )
              ((eq Global:EditMode "2") "/加前(F)/(B)" )
              ((eq Global:EditMode "3") "/加后(F)/(B)" )
              ((eq Global:EditMode "4") "/截取(F)/(B)" )
            )
            TmpTips 
            "]: "
          )
        )
        (while (and (setq Code  (grread T (+ 1 4 8) 2))(eq (car Code) 5)))
        (cond
          ((eq (type (cadr Code)) 'LIST);点选
            (if (setq TmpLst (nentselp (cadr Code)));点到了对象
                (progn
                    (setq OriEn (car TmpLst))
                    (if 
                        (and
                          (eq 'ENAME (type (last (last TmpLst))))
                          (member (cdr (assoc 0 (entget (last (last TmpLst))))) '("DIMENSION" "ARC_DIMENSION" "LARGE_RADIAL_DIMENSION"));如果是标注对象
                        )
                        (setq OriEn (last (last TmpLst)));顶层实体名(如果有)
                    )
                    (setq obj    (vlax-ename->vla-object OriEn)
                          ent    (entget OriEn)
                          EnType (cdr (assoc 0 ent))
                    )
                    (setq TmpUpText "" ;清空临时上标
                          NoGetSTR Nil ;设置标记
                    )
                    (cond
                      ((member EnType '("TEXT" "ATTRIB"))
                        (setq TmpUpText (cdr (assoc 1 ent)))
                        (setq Global:DwText "");清空下标
                      );CAD单行+CAD属性字
                      ((eq EnType "MULTILEADER")
                        (setq TmpUpText (cdr (assoc 304 ent)))
                        (setq Global:DwText "");清空下标
                      );CAD引线
                      ((eq EnType "ATTDEF")
                        (setq TmpUpText (vla-get-TagString obj))
                        (setq Global:DwText "");清空下标
                      );如果是属性定义, 则取"标记"
                      ((eq EnType "MTEXT" )
                        (setq TmpUpText (K:MText2Text (cdr (assoc 1 ent))))
                        (setq Global:DwText "");清空下标
                      );CAD多行
                      ((member EnType (list "DIMENSION" "ARC_DIMENSION" "LARGE_RADIAL_DIMENSION"))
                        (setq ObjNam (K:GetProp obj 'ObjectName);对象名
                              StyRud (Cdr (Assoc 45 (tblsearch "DIMSTYLE" (K:GetProp obj 'StyleName))));标注样式的舍入值
                              TmpMea (K:GetProp obj 'Measurement);测量值舍入
                              TmpOve (K:GetProp obj 'TextOverride);文本覆盖
                        )
                       
                        (setq TmpUpText 
                            (if (/= "" TmpOve)
                                TmpOve
                                (cond
                                    ((eq ObjNam "AcDbDiametricDimension");直径标注
                                      (strcat "%%C" (rtos (K:RoundVal TmpMea StyRud)))
                                    )
                                    ((eq ObjNam "AcDbRadialDimension");半径标注
                                      (strcat "R" (rtos (K:RoundVal TmpMea StyRud)))
                                    )
                                    ((member ObjNam (list "AcDb2LineAngularDimension" "AcDb3PointAngularDimension"));角度标注
                                      (strcat (rtos (K:RoundVal (* 180 (/ TmpMea pi)) StyRud)) "°")
                                    )
                                    (T 
                                      (rtos  (K:RoundVal TmpMea StyRud))
                                    )
                                )
                            );避免为空
                        );上标
                        (setq Global:DwText "");清空下标
                      );CAD标注：CAD半径+CAD直径+线性标注+对齐标注+角度标注+折弯标注+坐标标注

                      ((member EnType  (list "TCH_COMPOSING" "TCH_TEXT") )
                        (setq TmpUpText (K:GetProp obj 'Text))
                        (setq Global:DwText "");清空下标
                      );天正做法标注+天正单行
                      ((eq EnType "TCH_ELEVATION")
                            (setq BGLst (K:RtnBGLst obj))
                            (cond
                                ((eq Global:BrushTgt "1");刷上下标
                                    (if (vl-string-search "$" (car BGLst));多层标高时
                                      (progn
                                        (setq TmpUpText  (car BGLst))
                                        (setq Global:DwText "");清空下标
                                      )
                                      (if (eq (cadr BGLst) "") ;下标为空
                                          (setq TmpUpText     (car BGLst)
                                                Global:DwText "" ;清空下标
                                          )
                                          (setq TmpUpText  (strcat (car BGLst) "&" (cadr BGLst))
                                                Global:DwText "" ;清空下标
                                          )
                                      )
                                    )
                                )
                                ((eq Global:BrushTgt "2");仅刷上标
                                    (if (not (vl-string-search "$" (car BGLst)));非多层标高时取上标
                                        (setq TmpUpText (car BGLst))
                                    )
                                    (setq Global:DwText "");清空下标
                                )
                                ((eq Global:BrushTgt "3");仅刷下标
                                    (setq TmpUpText 
                                          (if (and (eq (cadr BGLst) "") (not (vl-string-search "$" (car BGLst))));下标为空且非多层标高时，取上标作为下标
                                              (car BGLst)
                                              (cadr BGLst)
                                          )
                                    )
                                )
                            )
                      );天正标高
                      ((eq EnType  "TCH_DRAWINGNAME")
                        (setq TmpUpText (K:GetProp obj 'NameText))
                        (setq Global:DwText "");清空下标
                      );天正图名
                      ((eq EnType "TCH_MTEXT")
                        (setq TmpUpText (cdr (assoc 1 ent)))
                        (setq Global:DwText "");清空下标
                      );天正多行
                      ((eq EnType "TCH_DRAWINGINDEX")
                        (setq TmpUpText (K:GetProp obj 'IndexLabel));上标
                        (setq Global:DwText "");清空下标
                      );天正索引图名
                      ((member EnType '("TCH_RADIUSDIM" "TCH_NORTHTHUMB" "TCH_SYMB_SECTION"))
                        (setq TmpUpText (K:GetProp obj 'Text));上标
                        (setq Global:DwText "");清空下标
                      );天正半径+天正直径+天正指北针+天正剖切符号
                      ((eq EnType "TCH_INDEXPOINTER")
                        (setq TmpUpText (K:GetProp obj 'IndexLabel));上标
                        (setq Global:DwText (K:GetProp obj 'DrawingLabel));下标
                      );天正指向索引+天正剖切索引
                      ((eq EnType "TCH_ARROW")
                        (setq TmpUpText (K:GetProp obj 'Text));上标
                        (if 
                          (or
                              (eq "在线端" (K:GetProp obj 'Alignment))
                              (eq "在箭头" (K:GetProp obj 'Alignment))
                          )
                          (setq Global:DwText "");清空下标
                          (setq Global:DwText (K:GetProp obj 'Text2));下标
                        )
                      );天正箭头引注
                      ((eq EnType "TCH_MULTILEADER")
                        (setq TmpUpText (K:GetProp obj 'UpText));上标
                        (setq Global:DwText (K:GetProp obj 'DownText));下标
                      );天正引出标注
                      ((eq EnType "TCH_COORD")
                        (setq TmpUpText (strcat "X=" (K:RealSTR4Pre (K:GetProp obj 'XValue) (K:GetProp obj 'Precision))))
                        (setq Global:DwText (strcat "Y=" (K:RealSTR4Pre (K:GetProp obj 'YValue) (K:GetProp obj 'Precision))))
                      );天正坐标标注
                      ((eq EnType "TCH_SPACE")
                        (setq TmpUpText (K:GetProp obj 'Name));上标
                        (setq Global:DwText (K:GetProp obj 'UseArea));下标
                      );天正房间面积
                      (t 
                        (princ (strcat "\n——★★★ 不可取： 不支持的对象类型! ★★★——\n"))
                        (setq NoGetSTR T)
                      )
                    )
                    (if NoGetSTR ;没有获取到文字
                        T ;继续循环
                        (progn ;获取到文字,但可能为空
                            (redraw OriEn 3) ;亮显对象
                            (if (eq Global:EditMode "4")
                                (progn
                                  (if (eq EnType "TCH_COMPOSING");天正做法标注
                                      (setq TmpUpText (K:GetTgtSTR Nil TmpUpText (atoi Global:GetSTRF) (atoi Global:GetSTRB) Nil))
                                  );上标
                                  (setq Global:DwText (K:GetTgtSTR Nil Global:DwText (atoi Global:GetSTRF) (atoi Global:GetSTRB) Nil));下标
                                )
                            )
                            (if 
                              (and
                                (eq Global:BrushTgt "3" );仅刷下标
                                (not (eq Global:DwText ""));取到了下标
                              )
                              (setq TmpUpText (K:FmtSTR4FA Global:DwText));下标给目标文字
                            )
                            (if (eq TmpUpText "");不存在目标文字
                                (progn
                                    (setq Global:UpText "");上标为空
                                    (princ (strcat "\n——★★★ 文字内容为空值 ★★★——\n"))
                                )
                                (progn 
                                  (setq Global:UpText (K:FmtSTR4FA TmpUpText))
                                  (princ (strcat "\n——★★★ 文字内容为 <" Global:UpText "> ★★★——\n"))
                                )
                            )
                            (if 
                              (and
                                  (eq Global:BrushTgt "1")
                                  (not (eq Global:DwText ""))
                              )
                              (progn
                                (setq Global:DwText (K:FmtSTR4FA Global:DwText))
                                (princ (strcat "\n——★★★ 文字下标为 <" Global:DwText "> ★★★——\n"))
                              )
                            )
                            
                            Nil ;退出循环
                        )
                    ) 
                )
                (progn
                    (princ "\n——★★★ 请选择对象或空格使用默认值 ★★★——\n")
                    T ;继续循环
                )
            )
          )
          ((or ;字母A
              (eq (cadr Code) 65)
              (eq (cadr Code) (+ 65 32))
            )
            (setq Global:UpText "");上标
            (setq Global:DwText "");下标
            (princ (strcat "\n——★★★ 文字内容已清空, 为空值 ★★★——\n"))
            (princ)
            Nil ;退出循环
          )
          ((or ;字母R
              (eq (cadr Code) 82)
              (eq (cadr Code) (+ 82 32))
            )
            (K:SetGetUpdVar T "FAWZSys1" Global:VarLst1);强制更新为默认
            (princ "\n——★★★ 文字刷模式已重置 ★★★——\n")
            (princ)
            T ;继续循环
          )
          ((or ;字母G
              (eq (cadr Code) 71)
              (eq (cadr Code) (+ 71 32))
            )
            (defun K:RtnNewUPT (UPT DwT)
                (if 
                    (or
                        (wcmatch UPT "*镀锌*,*不锈钢*")
                        (wcmatch DwT "*电镀*,*氟碳漆*,*螺栓*,*参见*,*详见*,详*图")
                    )
                    (strcat UPT "," DwT)
                    (strcat UPT DwT)
                )
            );当存在特殊符号时，添加英文逗号
            (princ "\n——★★★ 请选择含下标的天正箭头及引出标注! ★★★——\n")
            (princ "\n——★★★ 当上标含<镀锌、不锈钢>或下标含<电镀、氟碳漆、螺栓、参见、详见、详*图>时,上标后面将添加英文逗号! ★★★——\n")
            (while (setq SS (ssget ":S" '((0 . "TCH_ARROW,TCH_MULTILEADER")))) ;只选箭头和引出标注
                (setq Count 0);计数归零
                (repeat (setq i (sslength SS))
                  (setq obj    (vlax-ename->vla-object (ssname SS (setq i (1- i)))))
                  (cond 
                    ((eq (Vlax-Get obj 'ObjectName) "TDbSymbArrow") ;箭头
                        (if 
                          (or
                              (eq "齐线中" (K:GetProp obj 'Alignment))
                              (eq "齐线端" (K:GetProp obj 'Alignment))
                          )
                          (if (/= "" (K:GetProp obj 'Text2))
                              (progn
                                  (vlax-put-property obj 'Text
                                     (K:FmtSTR4FA (K:RtnNewUPT (K:GetProp obj 'Text) (K:GetProp obj 'Text2)))
                                  )
                                  (vlax-put-property obj 'Text2 "");清空下标
                                  (setq Count (1+ Count));统计成功的个数
                              )
                          )
                          (vlax-put-property obj 'Text2 "");清空下标
                        )
                    )
                    ((eq (Vlax-Get obj 'ObjectName) "TDbSymbMultiLeader") ;引出
                        (if (/= "" (K:GetProp obj 'DownText))
                            (progn
                              (vlax-put-property obj 'UpText
                                  (K:FmtSTR4FA (K:RtnNewUPT (K:GetProp obj 'UpText) (K:GetProp obj 'DownText)))
                              )
                              (vlax-put-property obj 'DownText "");清空下标
                              (setq Count (1+ Count));统计成功的个数
                            )

                        )
                    )
                  )
                )
                (if (eq Count 0) 
                  (princ "\n——★★★ 所选对象不含下标,未处理! ★★★——\n")
                  (princ (strcat "\n——★★★ 成功处理了<" (rtos Count 2 0) ">个对象! ★★★——\n"))
                )
            )
            (princ "\n——★★★ 未选择对象,程序退出! ★★★——\n")
            (setq YesUPSTR Nil);是否执行后续的刷字程序
            Nil ;退出循环
          )
          ((or ;字母Z
              (eq (cadr Code) 90)
              (eq (cadr Code) (+ 90 32))
            )
            (princ "\n——★★★ 请选择天正做法标注! ★★★——\n")
            (while (setq SS (ssget ":S" '((0 . "TCH_COMPOSING")))) ;只选做法标注
                (setq Count 0);计数归零
                (repeat (setq i (sslength SS))
                    (setq obj       (vlax-ename->vla-object (ssname SS (setq i (1- i))))
                          TmpUpText (K:FmtSTR4FA (K:GetProp obj 'Text))
                          TmpUpText (K:STR->Lst TmpUpText "\r\n") ;移除格式
                          TmpUpText (vl-remove-if '(lambda (xx) (eq xx "")) TmpUpText) ;移除空格
                    )
                    (if (> (length TmpUpText) 1)
                        (progn
                            (vlax-put-property obj 'Text (K:Lst->STR (reverse TmpUpText) "\r\n"))
                            (K:PutProp obj 'TextColor 7);字白色
                            (K:PutProp obj 'TextType "单行文字");单行文字
                            (K:PutProp obj 'TextBaseLen 5);线长5
                            (setq Count (1+ Count));统计成功的个数
                        )  
                    )
                )
                (if (eq Count 0) 
                  (princ "\n——★★★ 所选对象不含下标,未处理! ★★★——\n")
                  (princ (strcat "\n——★★★ 成功处理了<" (rtos Count 2 0) ">个对象! ★★★——\n"))
                )
            )
            (princ "\n——★★★ 未选择对象,程序退出! ★★★——\n")
            (setq YesUPSTR Nil);是否执行后续的刷字程序
            Nil ;退出循环
          )
          ((or ;字母D
              (eq (cadr Code) 68)
              (eq (cadr Code) (+ 68 32))
            )
            (cond
              ((eq Global:BrushTgt "1") 
                (setq Global:BrushTgt "2")
                (princ "\n——★★★ 文字仅刷->> 上标 ★★★——\n")
              )
              ((eq Global:BrushTgt "2") 
                (setq Global:BrushTgt "3")
                (princ "\n——★★★ 文字仅刷->> 下标 ★★★——\n")
              )
              ((eq Global:BrushTgt "3") 
                (setq Global:BrushTgt "1")
                (princ "\n——★★★ 文字会刷->> 上下标 ★★★——\n")
              )
            )
            T ;继续循环
          )
          ((or ;字母F
              (eq (cadr Code) 70)
              (eq (cadr Code) (+ 70 32))
            )
            (cond
              ((eq Global:EditMode "4") 
                (setq Global:EditMode "1")
                (princ "\n——★★★ 文字模式为->> 替换 ★★★——\n")
              )
              ((eq Global:EditMode "1") 
                (setq Global:EditMode "2")
                (princ "\n——★★★ 文字模式为->> 加前 ★★★——\n")
              )
              ((eq Global:EditMode "2") 
                (setq Global:EditMode "3")
                (princ "\n——★★★ 文字模式为->> 加后 ★★★——\n")
              )
              ((eq Global:EditMode "3") 
                (setq Global:EditMode "4")
                (princ "\n——★★★ 文字模式为->> 截取 ★★★——\n")
                (princ (strcat "\n——★★★ 字符串将取第<" Global:GetSTRF ">项之后, 将刷第<" Global:SetSTRB ">项之后 ★★★——\n"))
              )
            )
            T ;继续循环
          )
          ((or ;字母B
              (eq (cadr Code) 66)
              (eq (cadr Code) (+ 66 32))
            )
            (cond
              ((eq Global:EditMode "2") 
                (setq Global:EditMode "1")
                (princ "\n——★★★ 文字模式为->> 替换 ★★★——\n")
              )
              ((eq Global:EditMode "3") 
                (setq Global:EditMode "2")
                (princ "\n——★★★ 文字模式为->> 加前 ★★★——\n")
              )
              ((eq Global:EditMode "4") 
                (setq Global:EditMode "3")
                (princ "\n——★★★ 文字模式为->> 加后 ★★★——\n")
              )
              ((eq Global:EditMode "1") 
                (setq Global:EditMode "4")
                (princ "\n——★★★ 文字模式为->> 截取 ★★★——\n")
                (princ (strcat "\n——★★★ 字符串将取第<" Global:GetSTRF ">项之后, 将刷第<" Global:SetSTRB ">项之后 ★★★——\n"))
              )
            )
            T ;继续循环
          )
          ((and ;数字1
             (eq Global:EditMode "4") 
             (eq (cadr Code) 49)
           )
            (progn
              (initget 4);非负
              (setq Global:GetSTRF 
                  (cond 
                    ((getint (strcat  "\n→取：忽略第几项前：<" Global:GetSTRF ">")))
                    ((atoi Global:GetSTRF))
                  )
              )
              (setq Global:GetSTRF (rtos Global:GetSTRF 2 0))
            );忽略前项
            (progn
                (initget 4);非负
                (setq Global:GetSTRB 
                    (cond 
                      ((getint (strcat  "\n→取：忽略第几项后：<" Global:GetSTRB ">")))
                      ((atoi Global:GetSTRB))
                    )
                )
                (setq Global:GetSTRB (rtos Global:GetSTRB 2 0))
            );忽略后项
            (princ (strcat "\n——★★★ 取：截取字符串时将忽略前<" Global:GetSTRF ">项,和后<" Global:GetSTRB ">项 ★★★——\n"))
            T ;继续循环
          )
          ((and ;数字2
             (eq Global:EditMode "4") 
             (eq (cadr Code) 50)
           )
            (progn
              (initget 4);非负
              (setq Global:SetSTRF 
                  (cond 
                    ((getint (strcat  "\n→刷：保留第几项前：<" Global:SetSTRF ">")))
                    ((atoi Global:SetSTRF))
                  )
              )
              (setq Global:SetSTRF (rtos Global:SetSTRF 2 0))
            );忽略前项
            (progn
                (initget 4);非负
                (setq Global:SetSTRB 
                    (cond 
                      ((getint (strcat  "\n→刷：保留第几项后：<" Global:SetSTRB ">")))
                      ((atoi Global:SetSTRB))
                    )
                )
                (setq Global:SetSTRB (rtos Global:SetSTRB 2 0))
            );忽略后项
            (princ (strcat "\n——★★★ 刷：截取字符串时将保留前<" Global:SetSTRF ">项和后<" Global:SetSTRB ">项 ★★★——\n"))
            T ;继续循环
          )
          ((or  ;空格回车
              (eq (cadr Code) 13) ;回车
              (eq (cadr Code) 32) ;空格
           )
            (if (eq Global:UpText "");存在上标
              (princ "\n——★★★ 文字内容为空值 ★★★——\n")
              (princ (strcat "\n——★★★ 文字内容为 <" Global:UpText "> ★★★——\n"))
            )
            (if 
              (and
                (eq Global:BrushTgt "1")
                (not (eq Global:DwText ""));存在下标
              )
              (princ (strcat "\n——★★★ 文字下标为 <" Global:DwText "> ★★★——\n"))
            )
            Nil ;退出循环
          )
          (T
              (princ "\n——★★★ 请选择对象或输入正确的关键词! ★★★——\n")
              T ;继续循环
          )
        )
      )
    );获取源文字
    (setenv "K\\FAGlobal-UpText" Global:UpText);储存上标为环境变量
    (setenv "K\\FAGlobal-DwText" Global:DwText);储存下标为环境变量
    (K:SetGetUpdVar Nil "FAWZSys1" Global:VarLst1);更新变量(若无则设置为默认值)
    (K:SetGetUpdVar Nil "FAWZSys2" Global:VarLst2);更新变量(若无则设置为默认值)
    (while (and YesUPSTR (setq SS (ssget ":S" )))
      (if (eq (caar (setq SSData (ssnamex SS))) 1)  ;点选
          (progn
              (if (member (cdr (assoc 0 (entget (ssname SS 0)))) '("DIMENSION" "ARC_DIMENSION" "LARGE_RADIAL_DIMENSION"));CAD标注：CAD半径+CAD直径+线性标注+对齐标注+角度标注+坐标标注+弧长标注+折弯标注
                  (setq TgtPTen (ssname SS 0))
                  (setq TgtPT (trans (cadr (last (car SSData))) 0 1)
                        TmpLst (nentselp TgtPT)
                        TgtPTen (car TmpLst)
                  )
              );获取新对象
              (if (and TgtPTen (eq TgtPTen OriEn))
                  (progn
                    (redraw OriEn 3) ;重新亮显对象
                    (K:TextBrush4FA TgtPTen Global:BrushTgt Global:EditMode Global:SetSTRF Global:SetSTRB Global:UpText Global:DwText)
                  )
                  (K:TextBrush4FA TgtPTen Global:BrushTgt Global:EditMode Global:SetSTRF Global:SetSTRB Global:UpText Global:DwText)
              )
              ;(entupd (ssname SS 0));刷新
              ;(entupd TgtPTen);刷新
              (if 
                  (and
                    (eq 'ENAME (type (last (last TmpLst))))
                    (eq (cdr (assoc 0 (entget (last (last TmpLst))))) "INSERT");如果是块
                  )
                  (command "_.regen")
              );块就刷新
          )
          (repeat (setq i (sslength SS)) 
            (setq en (ssname SS (setq i (1- i))))
            (K:TextBrush4FA en Global:BrushTgt Global:EditMode Global:SetSTRF Global:SetSTRB Global:UpText Global:DwText)
          )
      )
    );更新文字
    (command "redraw");重画当前视口
    (if OriEn (redraw OriEn 4));取消亮显
    (foreach xx *Old_SysVar* (apply 'setvar xx));参数恢复
  (vla-endundomark CurDoc) ;结束编组
  (princ)
)

(progn ;基础函数
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
  ;四舍五入
  (defun K:RoundVal (OldVal Round)
      (if (= Round 0.0)
          (setq NewVal OldVal)
          (if (= 0 (setq FVar (fix (/ (+ OldVal (* Round 0.5)) Round))))
              (setq NewVal Round)
              (setq NewVal (* Round FVar))
          )
      )
      NewVal
  )
  ;多行文字转单行文字(去除无用格式符号) form 明经
  (defun K:MText2Text (MTextSTR / Regex STR) 
    (setq Regex (vlax-create-object "Vbscript.RegExp")) ;引用正则表达式控件
    (vlax-put-property Regex "IgnoreCase" 0) ;不忽略大小写
    (vlax-put-property Regex "Global" 1) ;匹配方式, 全文字匹配
    (setq STR MTextSTR)
    ;替换\\字符
    (vlax-put-property Regex "Pattern" "\\\\\\\\")
    (setq STR (vlax-invoke-method Regex "Replace" STR (chr 1)))
    ;替换\{字符
    (vlax-put-property Regex "Pattern" "\\\\{")
    (setq STR (vlax-invoke-method Regex "Replace" STR (chr 2)))
    ;替换\}字符
    (vlax-put-property Regex "Pattern" "\\\\}")
    (setq STR (vlax-invoke-method Regex "Replace" STR (chr 3)))
    ;删除段落缩进格式
    (vlax-put-property Regex "Pattern" "\\\\pi(.[^;]*);")
    (setq STR (vlax-invoke-method Regex "Replace" STR ""))
    ;删除制表符格式
    (vlax-put-property Regex "Pattern" "\\\\pt(.[^;]*);")
    (setq STR (vlax-invoke-method Regex "Replace" STR ""))
    ;删除堆迭格式
    (vlax-put-property Regex "Pattern" "\\\\S(.[^;]*)(\\^|#|\\\\)(.[^;]*);")
    (setq STR (vlax-invoke-method Regex "Replace" STR ""))
    ;删除字体、颜色、字高、字距、倾斜、字宽、对齐格式
    (vlax-put-property Regex  "Pattern" "(\\\\F|\\\\f|\\\\C|\\\\H|\\\\\T|\\\\Q|\\\\W|\\\\A)(.[^;]*);")
    (setq STR (vlax-invoke-method Regex "Replace" STR ""))
    ;删除下划线、删除线格式
    (vlax-put-property Regex "Pattern" "(\\\\L|\\\\O|\\\\l|\\\\o)")
    (setq STR (vlax-invoke-method Regex "Replace" STR ""))
    ;删除不间断空格格式
    (vlax-put-property Regex "Pattern" "\\\\~")
    (setq STR (vlax-invoke-method Regex "Replace" STR ""))
    ;删除换行符格式
    (vlax-put-property Regex "Pattern" "\\\\P")
    (setq STR (vlax-invoke-method Regex "Replace" STR ""))
    ;删除换行符格式(针对Shift+Enter格式)
    (vlax-put-property Regex "Pattern" "\n")
    (setq STR (vlax-invoke-method Regex "Replace" STR ""))
    ;删除{}
    (vlax-put-property Regex "Pattern" "({|})")
    (setq STR (vlax-invoke-method Regex "Replace" STR ""))
    ;替换回\\,\{,\}字符
    (vlax-put-property Regex "Pattern" "\\x01")
    (setq STR (vlax-invoke-method Regex "Replace" STR "\\"))
    (vlax-put-property Regex "Pattern" "\\x02")
    (setq STR (vlax-invoke-method Regex "Replace" STR "{"))
    (vlax-put-property Regex "Pattern" "\\x03")
    (setq STR (vlax-invoke-method Regex "Replace" STR "}"))
    (vlax-release-object Regex)
    STR
  )
  ;将字符串拆分成单字符列表
  (defun K:ExplodeSTR (STR / Defined STRDefined RtnSTR Pos)
    (setq Defined 
        (List 
          "%%130" "%%131" "%%132" "%%133" "%%134" ;1~4级钢筋符号+特殊钢筋
          "%%135" "%%136" "%%137" "%%138" ;L型钢+H型钢+槽型钢+工字钢
          "%%150" "%%151" "%%152" "%%153" "%%154" "%%155" "%%156" "%%157" "%%158" "%%159" ;罗马数字
          "%%177" "%%p" "%%P" ;正负号
          "%%c" "%%C" "%%D" "%%d" "%%%";直径符号+度数符号+%
          '("%%140" "%%141") '("%%142" "%%143") ;上下标开关
          '("%%200" "%%201") '("%%202" "%%203") '("%%204" "%%205") ;圆圈数字
        )
    )
    (while (> (strlen STR) 0)
      (cond
        ((setq STRDefined
            (vl-some 
              '(lambda (Sub / STRDefined) 
                (setq STRDefined (if (listp Sub) (car Sub) Sub))
                (if (eq (substr STR 1 (strlen STRDefined)) STRDefined) Sub)
              )
              Defined
            )
          )
          (if (listp STRDefined)
              (if (setq Pos (vl-string-search (cadr STRDefined) STR))
                (progn
                  (setq RtnSTR (cons (substr STR 1 (+ Pos (strlen (cadr STRDefined)))) RtnSTR))
                  (setq STR (substr STR (+ 1 Pos (strlen (cadr STRDefined)))))
                )
                (progn
                  (setq RtnSTR (cons STR RtnSTR))
                  (setq STR "");清空
                )
              )
              (progn
                (setq RtnSTR (cons STRDefined RtnSTR))
                (setq STR (substr STR (1+ (strlen STRDefined))))
              )
          )
        )
        ((> (ascii (substr STR 1 1)) 128) ;大于128为汉字
          (if 
            (and
              (>= (atoi (substr (ver) 13)) 2021)
              (/= (getvar "lispsys") 0)
            )
            (progn 
              (setq RtnSTR (cons (substr STR 1 1) RtnSTR))
              (setq STR (substr STR 2))
            )
            (progn 
              (setq RtnSTR (cons (substr STR 1 2) RtnSTR))
              (setq STR (substr STR 3))
            )
          )
        )
        (T
          (setq RtnSTR (cons (substr STR 1 1) RtnSTR))
          (setq STR (substr STR 2))
        )
      )
    )
    (reverse RtnSTR)
  )
  ;取出列表的前n项
  (defun K:Get_Fst4N (Lst Num / NewLst)
      (if (> Num 0)
        (progn
          (setq Num (min Num (length Lst)))
          (repeat Num 
            (setq NewLst (cons 
                          (nth (setq Num (1- Num)) Lst)
                          NewLst
                        )
            )
          ) 
        )
        (list "")
      )
  )
  ;取出列表第n项之后的内容
  (defun K:Get_Bak4N (Lst Num / NewLst)
      (reverse (K:Get_Fst4N (reverse Lst) (- (length Lst) Num)))
  )
  ;取刷时的目标文字,TgtSTR为Nil表示取中间文字。返回目标字符串
  (defun K:GetTgtSTR (IsSTR OriSTR NumF NumB TgtSTR / ExpLst TmpLst NewSTR)
      (if IsSTR
          (setq ExpLst (K:ExplodeSTR OriSTR))
          (setq ExpLst (K:STR->Lst OriSTR "\r\n"))
      );字符串是否为做法标注
      (if ExpLst
          (if TgtSTR
              (cond
                  ((= NumB NumF 0) TgtSTR);没取
                  ((<= (+ NumB NumF) (length ExpLst));中间极端时刚好吃完
                    (setq TmpLst
                        (append
                            (K:Get_Fst4N ExpLst NumF)
                            (list TgtSTR)
                            (K:Get_Bak4N ExpLst (- (length ExpLst) NumB))
                        )
                    )
                    (if IsSTR
                        (apply 'strcat TmpLst)
                        (K:Lst->STR TmpLst "\r\n")
                    )
                  )
                  (T 
                      (setq TmpLst
                          (append
                              (K:Get_Fst4N ExpLst NumF)
                              (list TgtSTR)
                              (if (< NumF (length ExpLst))
                                  (K:Get_Bak4N ExpLst (1+ NumF))
                              ) 
                          )
                      )
                      (if IsSTR
                          (apply 'strcat TmpLst)
                          (K:Lst->STR TmpLst "\r\n")
                      )
                  );吃多了有重叠:先保前面，后面的剩啥是啥
              );刷
              (progn
                  (setq TmpLst (K:Get_Bak4N (K:Get_Fst4N ExpLst (- (length ExpLst) NumB)) NumF));忽略后再忽略前
                  (if IsSTR
                    (apply 'strcat TmpLst)
                    (K:Lst->STR TmpLst "\r\n")
                  )
              ) 
          )
      )
  )
  ;根据标记拆分字符串成表@LeeMac
  (defun K:STR->Lst (STR Del / Len Lst Pos) 
    (setq Len (1+ (strlen Del)))
    (while (setq Pos (vl-string-search Del STR)) 
      (setq Lst (cons (substr STR 1 Pos) Lst)
            STR (substr STR (+ Pos Len))
      )
    )
    (reverse (cons STR Lst))
  )
  ;根据标记将字符串表表串联@LeeMac
  (defun K:Lst->STR (Lst Del / STR XX) 
    (setq STR (car Lst))
    (foreach XX (cdr Lst) (setq STR (strcat STR Del XX)))
    STR
  )
  ;字符串格式化括号,逗号等变为英文
  ;(K:FmtSTR4FA "800X500X10厚，:芝麻黑（）") -> "800*500*10厚,:芝麻黑()"
  (defun K:FmtSTR4FA (OriSTR / XX)
    ;|
      ;用NewS替换掉字符串中的OldS
      (defun K:ReplaceSTR (NewS OldS OriSTR) 
        (while (vl-string-search OldS OriSTR);找到了就替换
          (setq OriSTR (vl-string-subst NewS OldS OriSTR))
        )
        OriSTR
      )
      (foreach XX (list (list ":" "：")(list "(" "（") (list ")" "）")(list "," "，") (list "x" "X") (list "*" "x")) 
          (setq OriSTR (apply 'K:ReplaceSTR (append XX (list OriSTR))))
      );替换括号逗号以及星号
    |;
    OriSTR
  )
  ;浮点数字符串:四舍五入到指定小数位(含处理正负零)
  (defun K:RealSTR4Pre (RealSTR PreSTR / HH:rtosr1 Pos TgtPre FReal)
    ;四舍五入到小数位@自贡黄明儒
    (defun HH:rtosr1 (Real TgtPre / Old_DIM STR) 
      (setq Old_DIM (getvar "DIMZIN"))
      (setvar "DIMZIN" 0)
      (setq STR (rtos Real 2 TgtPre))
      (setvar "DIMZIN" Old_DIM)
      STR
    )
    (setq TgtPre (- (strlen PreSTR) (1+ (vl-string-search "." PreSTR))));小数点后面有几个零
    (cond
        ((or (eq (type RealSTR) 'INT)(eq (type RealSTR) 'Real))
          (setq NewSTR (HH:rtosr1 RealSTR TgtPre))
        );整数或者实数则直接取
        ((eq (type RealSTR) 'STR)
            (if (setq Pos (vl-string-search "%%P" (strcase RealSTR)))
                (setq RealSTR (substr RealSTR (+ Pos (1+ 3))))
            );删除正负零(如果有)
            (if (setq FReal (distof RealSTR 2));有浮点数
                (setq NewSTR (HH:rtosr1 FReal TgtPre))
                (setq NewSTR RealSTR)
            );取精度浮点数(如果有)
        )
        (T RealSTR)
    )
  )
  ;返回处理精度后的天正标高值
  (defun K:RtnBGLst (obj / TmpSTR TchPre ExpLst TgtPos) 
    (setq TmpSTR (K:GetProp obj 'Text)
          TchPre (K:GetProp obj 'Precision)
    )
    (if (vl-string-search "$" TmpSTR)  ;含多层标高
      (progn 
        (setq TmpSTR (K:Lst->STR 
                      (mapcar 
                        '(lambda (XX / ExpLst qm hm) 
                            (setq ExpLst (K:ExplodeSTR XX));分解文字
                            (if (setq TgtPos (vl-position "&" ExpLst));单层带注释
                                (progn 
                                  (setq qm (apply 'strcat (K:Get_Fst4N ExpLst TgtPos))
                                        hm (apply 'strcat (K:Get_Bak4N ExpLst (1+ TgtPos)))
                                        qm (K:RealSTR4Pre qm TchPre) ;处理上标精度
                                  )
                                  (if (eq 0.0 (distof qm 2));标高为0则添加正负号
                                      (strcat "%%P" qm "&" hm)
                                      (strcat qm "&" hm)
                                  )
                                )
                                (K:RealSTR4Pre XX TchPre) ;单层不带注释
                            )
                          )
                        (K:STR->Lst TmpSTR "$") ;拆分多层标高
                      ) ;处理上标精度
                      "$"
                    ) ;合并多层标高
        )
        (list TmpSTR "")
      )
      (if 
        (setq ExpLst (K:ExplodeSTR TmpSTR)
              TgtPos (vl-position "&" ExpLst)
        );单层带注释
        (progn 
          (setq qm (apply 'strcat (K:Get_Fst4N ExpLst TgtPos))
                hm (apply 'strcat (K:Get_Bak4N ExpLst (1+ TgtPos)))
                qm (K:RealSTR4Pre qm TchPre) ;处理上标精度
          )
          (if (eq 0.0 (distof qm 2));标高为0则添加正负号
              (list (strcat "%%P" qm) hm)
              (list qm hm)
          )
        )
        (progn 
          (setq qm (K:RealSTR4Pre TmpSTR TchPre))
          (if (eq 0.0 (distof qm 2)) 
              (list (strcat "%%P" qm) "")
              (list qm "")
          )
        );单层不带注释
      )
    )
  )
)

(if (not (getenv "K\\ToolsIsExit"))
    (princ "\n——★★★ 阿甘文字刷由Kucha优化, 调用命令: FA ★★★——\n")
)(princ)

