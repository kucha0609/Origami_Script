;|统计数据@Kucha
  1-输入命令GG,提示选择模式
  2-根据选择的模式，提示选择对应的对象。
  3-统计信息成表。提示选择表格插入点，输入关键词也可将表输出到外部
|;

;Global:GCLAdd
;Global:GCLMde
;Global:GCLUmm
;Global:AllDimSca
;Global:TabNum
(if (null vlax-dump-object) (vl-load-com));将Visual LISP扩展功能加载到 AutoLISP
(progn ;基础函数
  ;补齐字符串前导零,强制满足位数
  (defun K:AddZero4STR (STR Len) 
    (repeat (- Len (strlen STR)) 
      (setq STR (strcat "0" STR))
    )
    STR
  )
  ;使用分隔符串联字符串@LeeMac
  (defun K:Lst->STR (Lst Del / STR )
    (setq STR (car Lst))
    (foreach itm (cdr Lst) (setq STR (strcat STR Del itm)))
    STR
  )
  ;窗口交互@LeeMac
  (defun K:PopupWindows (Title Msg bit / wsh rtn) 
    ;http://lee-mac.com/popup.html
    (if (setq wsh (vlax-create-object "wscript.shell")) 
      (progn 
        (setq rtn (vl-catch-all-apply 'vlax-invoke-method 
                                      (list wsh 'popup Msg 0 Title bit)
                  )
        )
        (vlax-release-object wsh)
        (if (not (vl-catch-all-error-p rtn)) rtn)
      )
    )
  )

  ;生成填充实体的并返回图元表：(K:GetHatchBD 填充实体 边界层(在填充层？))
  (defun K:GetHatchBD (En OriLay 
                            / K:GetEnDXF K:Arc->Bulge K:LineArc2PL K:ElAng->Par  
                            BoundLst ent HLay PathNum PathBD1 PathBD2
                            PathTyp EdgTyp Cvt2PLst DATA VtxNum HasBlg PtLst IsClsd TgtEn
                            StaAng EndAng ISCCLK ERatio 
                            KnpNum CtrNum Front KnpLst CtrLst
                            )
    (progn ;基础函数
        ;获取实体DXF组码值
        (defun K:GetEnDXF (key en) (cdr (assoc key en)))
        ;圆弧数据转多段线数据@LEEMAC
        (defun K:Arc->Bulge (Cen Rad StaAng EndAng ) 
          (mapcar 'cons '(10 42 10)
              (list 
                (polar Cen StaAng Rad)
                ((lambda (a) (/ (sin a) (cos a))) 
                  (/ (rem (+ pi pi (- EndAng StaAng)) (+ pi pi)) 4.0)
                )
                (polar Cen EndAng Rad)
              )
          )
        )
        ;直线和圆弧转多段线数据处理@Kucha
        (defun K:LineArc2PL (OldLst / Fun NewLst Tmp BseLst BseVar Pos item) 
            ;|
              (setq OldLst
                (list 
                  (list 
                    (list 10 -1474.19 -1780.16 0.0)
                    (list 42 0.0)
                    (list 10 -1423.16 -1780.16 0.0)
                  )
                  (list 
                    (list 10 -1423.16 -1780.16 0.0)
                    (list 42 0.0)
                    (list 10 -1423.16 -1729.13 0.0)
                  )
                  (list 
                    (list 10 -1474.19 -1729.13 0.0)
                    (list 42 0.0)
                    (list 10 -1474.19 -1780.16 0.0)
                  )
                  (list 
                    (list 10 -1423.16 -1729.13 0.0)
                    (list 42 0.0)
                    (list 10 -1474.19 -1729.13 0.0)
                  )
                )
              )
            |;
            (setq OldLst (vl-sort OldLst
                           '(lambda (a b) 
                              (< (cadr (car a)) (cadr (last b)))
                            )
                         )
            )
            (setq Fun (lambda (a b) 
                        (if (equal (Last a) (caar b) 0.01);第一项的最后等于第二项的第一
                            (progn
                              (setq Tmp (append Tmp (cdar b)))
                              (Fun Tmp (cdr b))
                            )
                            (list b Tmp)
                        )
                    )
            )
            (if OldLst 
                (cons 
                    (append
                      (car OldLst)
                      (cadr (setq NewLst (Fun (car OldLst) (cdr OldLst))))
                    )
                    (K:LineArc2PL (car NewLst))
                )
            )
        )
        ;椭圆真实角度转参数@edata
        (defun K:ElAng->Par (Ang Ratio) 
            ;(K:ElAng->Par 真实弧度 短长轴比率)
            (if (and (> Ang (* pi 0.5)) (<= Ang (* pi 1.5))) 
                (- (atan (/ (/ (sin Ang) (cos Ang)) Ratio)) pi);当角度值90<Ang≤270时，减掉180
                (atan (/ (/ (sin Ang) (cos Ang)) Ratio))
            )
        )
    )
    (setq  BoundLst nil) ;生成的边界线图元表
    (if (and 
          (setq ent (entget En))
          (= "HATCH" (K:GetEnDXF 0 ent))
        )
        (progn
          (setq HLay (if OriLay  (K:GetEnDXF 8 ent)(getvar "CLAYER"));填充图层
                PathNum (K:GetEnDXF 91 ent);路径环数
                PathBD1 Nil
                PathBD2 Nil
          )
          (repeat PathNum 
              (setq ent (member (assoc 92 ent) ent))
              (setq PathTyp (cdr (car ent)));路径环类型
              (setq VtxNum (K:GetEnDXF 93 ent));当路径环为多段线时表示顶点数量，否则表示边的数量
              (if (> (boole 1 PathTyp 2) 0);路径环是多段线
                (progn
                  (setq ent (member (assoc 72 ent) ent))
                  (setq HasBlg (cdr (car ent)));当路径环为多段线时表示凸度标志，否则表示边类型

                  (setq PtLst nil)
                  (setq IsClsd (K:GetEnDXF 73 ent));当路径环为多段线时表示闭合标志
                  (repeat VtxNum
                      (setq ent (member (assoc 10 (cdr ent)) ent))
                      (setq PtLst (cons (assoc 10 ent) PtLst))
                      (if (> HasBlg 0) ;有凸度
                        (setq PtLst (cons (assoc 42 ent) PtLst))
                      )
                  )
                  (setq TgtEn 
                      (entmakeX 
                          (append
                              (list 
                                  '(0 . "LWPOLYLINE")
                                  '(100 . "AcDbEntity")
                                  '(100 . "AcDbPolyline")
                                  (cons 8 HLay);填充图层
                                  (cons 90 VtxNum)
                                  (cons 70 IsClsd)
                              )
                              (reverse PtLst)
                          )
                      )
                  )
                  (setq PathBD1 (cons TgtEn PathBD1));收集边界图元
                )
                (progn
                  (progn
                    (setq Cvt2PLst NIL)
                    (repeat VtxNum 
                      (setq ent (member (assoc 72 ent) ent));回到边起点
                      (setq EdgTyp (K:GetEnDXF 72 ent));边类型
                      (cond 
                        ((eq EdgTyp 1);直线
                            (setq ent (cdr ent));跳到下一段
                            (setq DATA
                                  (list 
                                    (cons 10 (K:GetEnDXF 10 ent))
                                    (cons 42 0.0)
                                    (cons 10 (K:GetEnDXF 11 ent))
                                  )
                            )
                            (if (not (member DATA Cvt2PLst)) 
                                (setq Cvt2PLst (cons DATA Cvt2PLst))
                            );收集数据
                        )
                        ((eq EdgTyp 2);圆OR圆弧
                            (setq ent (cdr ent));跳到下一段
                            (setq StaAng (K:GetEnDXF 50 ent);起点角度
                                  EndAng (K:GetEnDXF 51 ent);终点角度
                                  ISCCLK (K:GetEnDXF 73 ent);逆时针标记
                            )
                            (if (equal (- EndAng StaAng) 6.28319 1.0e-005);起点终点差360度为圆
                              (progn 
                                (setq TgtEn (entmakeX 
                                              (list 
                                                (cons 0 "CIRCLE")
                                                (cons 8 HLay);填充图层
                                                (assoc 10 ent)
                                                (assoc 40 ent)
                                              )
                                            )
                                )
                                (setq PathBD2 (cons TgtEn PathBD2));收集边界图元
                              )
                              (progn 
                                (setq DATA
                                    (if (eq ISCCLK 0)
                                        (K:Arc->Bulge (K:GetEnDXF 10 ent) (K:GetEnDXF 40 ent) (- EndAng) (- StaAng))
                                        (K:Arc->Bulge (K:GetEnDXF 10 ent) (K:GetEnDXF 40 ent) StaAng EndAng)
                                    )
                                )
                                (if (not (member DATA Cvt2PLst)) 
                                    (setq Cvt2PLst (cons DATA Cvt2PLst))
                                );收集数据
                              )
                            )
                            
                        )
                        ((eq EdgTyp 3);椭圆OR椭圆弧
                          (setq ent (cdr ent));跳到下一段
                          (setq StaAng (K:GetEnDXF 50 ent);起点角度
                                EndAng (K:GetEnDXF 51 ent);终点角度
                                ISCCLK (K:GetEnDXF 73 ent);逆时针标记
                                ERatio (K:GetEnDXF 40 ent);短长轴比率
                          )
                          (if (equal (- EndAng StaAng) 6.28319 1.0e-005);起点终点差360度为圆
                            (progn
                              (setq TgtEn 
                                  (entmakeX 
                                      (list 
                                        '(0 . "ELLIPSE") 
                                        '(100 . "AcDbEntity")
                                        '(100 . "AcDbEllipse")
                                        (cons 8 HLay);填充图层
                                        (assoc 10 ent)
                                        (assoc 11 ent)
                                        (assoc 40 ent)
                                        (cons 8 HLay);填充图层
                                        (cons 41 0.0)
                                        (cons 42 (* 2 pi))
                                      )
                                  )
                              )
                              (setq PathBD2 (cons TgtEn PathBD2));收集边界图元
                            )
                            (progn
                              (setq TgtEn 
                                  (entmakeX 
                                      (list 
                                        '(0 . "ELLIPSE") 
                                        '(100 . "AcDbEntity")
                                        '(100 . "AcDbEllipse")
                                        (cons 8 HLay);填充图层
                                        (assoc 10 ent)
                                        (assoc 11 ent)
                                        (assoc 40 ent)
                                        (cons 8 HLay);填充图层
                                        (if (eq ISCCLK 0) ;逆时针
                                          (progn 
                                            (cons 41 (K:ElAng->Par (- EndAng) ERatio))
                                            (cons 42 (K:ElAng->Par (- StaAng) ERatio))
                                          )
                                          (progn 
                                            (cons 41 (K:ElAng->Par StaAng ERatio))
                                            (cons 42 (K:ElAng->Par EndAng ERatio))
                                          )
                                        )
                                      )
                                  )
                              )
                              (setq PathBD2 (cons TgtEn PathBD2));收集边界图元
                            )
                          )
                        )
                        ((eq EdgTyp 4);样条曲线
                            (setq ent (cdr ent));跳到下一段
                            (progn
                                (setq KnpNum (K:GetEnDXF 95 ent);节点数
                                      CtrNum (K:GetEnDXF 96 ent);控制点数
                                )

                                (setq Front (list 
                                              '(0 . "SPLINE")
                                              (cons 100 "AcDbEntity")
                                              (cons 100 "AcDbSpline")
                                              (cons 8 HLay);填充图层
                                              (cons 
                                                70
                                                (+ 
                                                  (if (> VtxNum 1) 0 1)
                                                  8
                                                  (* 2 (K:GetEnDXF 73 ent));有理
                                                  (* 4 (K:GetEnDXF 74 ent));周期
                                                )
                                              )
                                              (cons 71 (K:GetEnDXF 94 ent));阶数
                                              (cons 72 KnpNum);节点数
                                              (cons 73 CtrNum);控制点数
                                            )
                                )
                              
                                (setq KnpLst nil CtrLst nil)
                                (setq ent (member (assoc 40 ent) ent))
                                  (repeat KnpNum 
                                    (setq KnpLst (cons (car ent) KnpLst))
                                    (setq ent (cdr ent))
                                  )
                                (setq ent (member (assoc 10 ent) ent))
                                  (repeat CtrNum 
                                    (setq CtrLst (cons (car ent) CtrLst))
                                    (setq ent (cdr ent))
                                  )
                            )
                            (setq TgtEn (entmakeX (append Front (reverse KnpLst) (reverse CtrLst))))
                            (setq PathBD2 (cons TgtEn PathBD2));收集边界图元
                        )
                      )
                    )
                    (if Cvt2PLst
                        (progn
                          (setq Cvt2PLst (K:LineArc2PL (mapcar 'reverse Cvt2PLst)));首尾颠倒来一次
                          (setq Cvt2PLst (K:LineArc2PL (mapcar 'reverse Cvt2PLst)));首尾颠倒再来一次
                          (foreach XX Cvt2PLst
                              (setq TgtEn 
                                    (entmakeX 
                                      (append
                                        (list 
                                            '(0 . "LWPOLYLINE")
                                            '(100 . "AcDbEntity")
                                            '(100 . "AcDbPolyline")
                                            (cons 8 HLay);填充图层
                                            (cons 70 1)
                                            (cons 90 (1+ (fix (* 0.5 (length XX)))))
                                        )
                                        XX
                                      )
                                    )
                              )
                              (setq PathBD2 (cons TgtEn PathBD2));收集边界图元
                          )
                        )
                    )
                  )
                )
              )
          )
          (setq BoundLst (append PathBD1 PathBD2));收集边界图元
        )
    )
    BoundLst
  )

  (defun K:PatExists-P (PatNam / Old_HPNam result)
    (setq Old_HPNam (getvar "HPNAME"))
    (if (not (vl-catch-all-error-p (vl-catch-all-apply 'setvar (list "HPNAME" PatNam))))
        (and(setvar "HPNAME" Old_HPNam))
    )
  )

  ;根据数据的第一项合并计数(Key DATA Other)
  (defun GG:GetDataLst (KeyLst TgtLst / itm) 
    (if (setq itm (assoc (car KeyLst) TgtLst)) 
        (subst 
            (list
              (car KeyLst) 
              (+ (cadr KeyLst) (cadr itm))
              (max (caddr KeyLst) (caddr itm));取较大的值
            )
            itm
            TgtLst
        )
        (cons KeyLst TgtLst)
    )
  )
  ;创建填充图案块
  (defun GG:MakeHatchBlk (BlkNam PatNam PatSca / i TmpNam)
    ;由UCS点外扩得到WCS矩形坐标表@Kucha
    (defun T:GetRec4PT (UCSPT XV YV)
      (setq XV (abs XV) YV (abs YV))
      (mapcar
        '(lambda(xx) (mapcar '+ UCSPT xx))
        (list
            (list (- XV) (- YV) 0.0)
            (list (- XV) YV 0.0)
            (list XV YV 0.0)
            (list XV (- YV) 0.0)
        )
      )
    )
    ;WCS点表生成多段线
    (defun T:MakeLWPOLYLINE (PTLst PLLay PLCol / XX) 
      (entmake
        (append 
          (list 
            (cons 0 "LWPOLYLINE")
            (cons 100 "AcDbEntity")
            (cons 100 "AcDbPolyline")
            (cons 8 (if PLLay PLLay "0"))
            (cons 62 (if (and PLCol (< 0 (abs PLCol) 256)) PLCol 7))
            (cons 90 (length PTLst))
            (cons 70 1);闭合
          )
          (mapcar '(lambda (XX)(cons 10 XX)) PTLst)
        )
      )
    )
    ;点表生成填充@ElpanovEvgeniy
    (defun T:MakeHatch4PTLst (WCSLst PatNam PatLay PatCol PatSca)
        (entmake 
          (apply 
            'append
            (list 
              (list 
                (cons 0 "HATCH")
                (cons 100 "AcDbEntity")
                (cons 410 "Model")
                (cons 100 "AcDbHatch")
                (cons 10 '(0.0 0.0 0.0))
                (cons 210 (trans '(0 0 1) 1 0 T ))
                (if (wcmatch PatNam "USER*")
                    (cons 2 "_USER")
                    (cons 2 PatNam)
                )
                (cons 8 (if PatLay PatLay "0"))
                (cons 62 (if (and PatCol (< 0 (abs PatCol) 256)) PatCol 7))
                (cons 70 0);实体填充？
                (cons 71 0)
                (cons 91 (length WCSLst))
              )
              (apply 
                'append
                (mapcar 
                  '(lambda (XX) 
                    (apply 
                      'append
                      (list 
                        (list (cons 92 7) (cons 72 1) (cons 73 1) (cons 93 (/ (length XX) 2)))
                        XX
                        (list (cons 97 0))
                      )
                    )
                  )
                  WCSLst
                )
              )
              (list 
                (cons 75 0)
                (cons 76 1)
                (cons 52 (- 0.0 (angle '(0 0 0) (trans (getvar "UCSXDIR") 0 (trans '(0 0 1) 1 0 T )))))
                (cons 41 PatSca)
                (if (and 
                      (wcmatch PatNam "USER*")
                      (wcmatch PatNam "*-D")
                    )
                    (cons 77 1);双向
                    (cons 77 0)
                )
                (cons 78 1)
                (cons 53 (- 0.0 (angle '(0 0 0) (trans (getvar "UCSXDIR") 0 (trans '(0 0 1) 1 0 T )))))
                (cons 43 0.)
                (cons 44 0.)
                (cons 45 1.)
                (cons 46 1.)
                (cons 79 0)
                (cons 47 1.)
                (cons 98 2)
                (cons 10 '(0.0 0.0 0.0))
                (cons 10 '(0.0 0.0 0.0))
                (cons 451 0)
                (cons 460 0.0)
                (cons 461 0.0)
                (cons 452 1)
                (cons 462 1.0)
                (cons 453 2)
                (cons 463 0.0)
                (cons 463 1.0)
                (cons 470 "LINEAR")
              )
            )
          )
        )
    )
    (setq i 0)
    (setq TmpNam BlkNam)
    (while (tblsearch "BLOCK" TmpNam)
        (setq TmpNam (strcat BlkNam "-" (itoa (setq i (1+ i)))))
    );查找块名避免重复
    (setq BlkNam TmpNam)
    (progn
      (entmake (list (cons 0 "Block") (cons 2 BlkNam) (cons 70 0) (cons 10 '(0.0 0.0 0.0))))
        (T:MakeLWPOLYLINE (T:GetRec4PT (list 0.0 0.0 0.0) 10 4) "0" 250)
        (T:MakeLWPOLYLINE (T:GetRec4PT (list 0.0 0.0 0.0) 9 3) "0" 1)
        (T:MakeHatch4PTLst 
            (list
              (apply 'append
                (mapcar
                  '(lambda(xx) 
                      (list
                          (cons 10 XX)
                          (cons 42 0.0)
                      )
                  )
                  (T:GetRec4PT (list 0.0 0.0 0.0) 9 3)
                )
              )
            )
            PatNam
            "0" 8 PatSca
        )
      (entmake (list (cons 0 "ENDBLK")))
    );创建块 
    BlkNam
  )
  ;设置块到表
  (defun GG:SetBlk2Tab (obj row col blk) 
    (eval 
      (list 
        'defun
        'GG:SetBlk2Tab
        '(obj row col blk)
        (cons 
          (if (vlax-method-applicable-p obj 'setblocktablerecordid32) 
            'vla-setblocktablerecordid32
            'vla-setblocktablerecordid
          )
          (list 
            'obj
            'row
            'col
            (list 'GG:ObjectID (list 'vla-item (vla-get-blocks CurDoc) 'blk))
            ':vlax-true
          )
        )
      )
    )
    (GG:SetBlk2Tab obj row col blk)
  )
  ;获取对象ID
  (defun GG:ObjectID (obj) 
    (eval 
      (list 
        'defun
        'GG:ObjectID
        '(obj)
        (cond 
          ((not (wcmatch (getenv "PROCESSOR_ARCHITECTURE") "*64*"))
          '(vla-get-objectid obj)
          )
          ((= 'subr (type vla-get-objectid32))
          '(vla-get-objectid32 obj)
          )
          ((list 'vla-getobjectidstring (vla-get-utility CurDoc) 'obj ':vlax-false))
        )
      )
    )
    (GG:ObjectID obj)
  )
  ;获取填充颜色RGB或索引色
  (defun GG:GetHatchCol (Hen)
    ;(setq Hen (car (nentsel)))
    (setq Hen
        (if (Assoc 62 (Entget Hen))
            Hen
            (tblobjname "layer" (cdr (Assoc 8 (Entget Hen))))
        )
    );对象或图层
    (if (Assoc 420 (Entget Hen));有RGB
        (K:Lst->STR 
          (mapcar 
            '(lambda (x) 
              (rtos 
                (lsh 
                  (lsh 
                    (fix 
                      (cdr (Assoc 420 (Entget Hen)))
                    )
                    x
                  )
                  -24
                )
                2
                0
              )
            )
            '(8 16 24)
          )
          ";"
        )
        (if (eq 0 (setq TmpCol (cdr (Assoc 62 (Entget Hen)))))
            "ByBlock"
            (rtos TmpCol 2 0)
        )
    )
  )
  ;创建表格样式
  (defun GG:CreateTabSty (StyNam MaxTxt MinTxt Margin / dictObj TabSty)
      ;https://hyperpics.blogs.com/beyond_the_ui/2012/07/creating-a-table-style-with-autolisp-and-the-activex-api.html
      ;; 获取 Dictionary 集合和 TableStyle 字典
      (setq dictObj (vla-Item (vla-get-Dictionaries (vla-get-activedocument (vlax-get-acad-object))) "acad_tablestyle"))
      (if (vl-catch-all-error-p (vl-catch-all-apply 'vla-item (list dictObj StyNam)))
          (progn
                ;创建自定义表格
                ;(setq StyNam "WorkTools")
                (setq TabSty (vla-AddObject dictObj StyNam "AcDbTableStyle"))

                ;样式名称和注释
                (vla-put-Name TabSty StyNam)
                (vla-put-Description TabSty "用于统计数据")

                ;设置样式的位标志值
                (vla-put-BitFlags TabSty 1)

                ;设置表格的方向，从上到下或从下到上
                (vla-put-FlowDirection TabSty acTableTopToBottom)

                ;; Sets the supression of the table header
                (vla-put-HeaderSuppressed TabSty :vlax-false)
                ;; Sets the supression of the table title
                (vla-put-TitleSuppressed TabSty :vlax-false)
              
                ;水平边距+垂直边距
                (vla-put-HorzCellMargin TabSty Margin)
                (vla-put-VertCellMargin TabSty Margin)

                ;文字居中对齐
                (vla-SetAlignment TabSty (+ acDataRow acTitleRow) acMiddleCenter)
                (vla-SetAlignment TabSty acHeaderRow acMiddleCenter)

                ;|设置标题行和表头行的背景颜色
                  (setq colObj (vlax-create-object (strcat "AutoCAD.AcCmColor." (substr (getvar "ACADVER") 1 2))))
                  (vla-SetRGB colObj 98 136 213)
                  (vla-SetBackgroundColor TabSty (+ acHeaderRow acTitleRow) colObj)
                  ;; Release the color object
                  (vlax-release-object colObj)
                |;

                ;清除数据行的背景颜色
                (vla-SetBackgroundColorNone TabSty acDataRow :vlax-true)
                ;|
                  ;设置标题行底部网格颜色
                  (vla-SetRGB colObj 0 0 255)
                  (vla-SetGridColor TabSty acHorzBottom acTitleRow colObj)
                  
                  ;设置标题行的底部网格线线宽
                  (vla-SetGridLineWeight TabSty acHorzBottom acTitleRow acLnWt025)
                |;
                ;为数据行和标题行设置可见的网格水平线
                (vla-SetGridVisibility TabSty acHorzInside  (+ acHeaderRow acDataRow) :vlax-true)
                ;设置文本样式
                (vla-SetTextStyle TabSty (+ acDataRow acHeaderRow acTitleRow) "Standard")
                ;设置标题、表头和数据行的文本高度
                (vla-SetTextHeight TabSty acTitleRow MaxTxt)
                (vla-SetTextHeight TabSty (+ acDataRow acHeaderRow) MinTxt)
                (setvar 'ctablestyle StyNam)
          )
          (setvar 'ctablestyle StyNam)
      )
      (princ)
  )
  ;创建表格
  (defun GG:CreateDataTab (StyNam TabMde TabUmm TgtLst TabNum
                            / TabType1 TabType2 TmpPT hgt Tab col row itm XX
                            StaNum FlieNam OpenFile XX TmpNam
                        )
      (setq hgt
          (vla-gettextheight
              (vla-item
                  (vla-item (vla-get-dictionaries (vla-get-activedocument (vlax-get-acad-object))) "acad_tablestyle")
                  StyNam
                  ;(getvar 'ctablestyle)
              )
              acdatarow
          )
      );字高
      (while ;get*
        (progn 
          (initget (+ 2 4) "D E U N") ;非零非负关键词
          (setq TmpPT (getpoint 
                          (strcat 
                            "\n→请指定表格插入点或空格比例 [比例(D)_" (rtos TmpDimSca 2 1) "/输出表格(E)"
                            (if (eq Global:GCLUmm "1") "/当前单位:毫米(U)" "/当前单位:米(U)")
                            "/附表序号(N)_" (rtos Global:TabNum 2 0) "]"
                          )
                      )
          )
          (setq TabType1
              (strcat
                "附表"
                (rtos TabNum 2 0)
                ":"
                (cond 
                  ((eq TabMde "A") "长度统计表")
                  ((eq TabMde "B") "面积统计表")
                  ((eq TabMde "C") "面积统计表")
                  ((eq TabMde "D") "面积统计表")
                  ((eq TabMde "E") "图块统计表")
                  ((eq TabMde "F") "编号统计表")
                )
                
              )
          )
          (setq TabType2
              (cond 
                ((eq TabMde "A") 
                  (list
                    (cons "序号" 10)
                    (cons "图层名称" 40)
                    (cons "线长(米)" 25)
                  )
                )
                ((eq TabMde "B") 
                  (list
                    (cons "序号" 10)
                    (cons "图案图例" 20)
                    (cons "图案名称" 40)
                    (cons "面积(平方米)" 25)
                  )
                )
                ((eq TabMde "C") 
                  (list
                    (cons "序号" 10)
                    (cons "图案颜色" 40)
                    (cons "面积(平方米)" 25)
                  )
                )
                ((eq TabMde "D") 
                  (list
                    (cons "序号" 10)
                    (cons "图层名称" 40)
                    (cons "面积(平方米)" 25)
                  )
                )
                ((eq TabMde "E") 
                  (list
                    (cons "序号" 10)
                    (cons "块图例" 20)
                    (cons "块名称" 40)
                    (cons "块数量(个)" 25)
                  )
                )
                ((eq TabMde "F") 
                  (list
                    (cons "序号" 10)
                    (cons "编号及数量" 25)
                    (cons "尺寸(cm)" 40)
                    (cons "备注" 25)
                  )
                )
              )
          )
          (cond 
            ((and TmpPT (eq (type TmpPT) 'LIST));指定了点
              (setq TgtLst 
                      (mapcar 
                        '(lambda (x) 
                            (list 
                                (if (eq TabMde "F")
                                    (strcat (car x) "x" (rtos (cadr x) 2 0) "个")
                                    (car x)
                                );名称/编号
                                (rtos 
                                  (if (eq TabUmm "1")
                                      (/ (cadr x)
                                          (cond
                                              ((eq TabMde "A") 1000)
                                              ((eq TabMde "B") 1000000)
                                              ((eq TabMde "C") 1000000)
                                              ((eq TabMde "D") 1000000)
                                              ((eq TabMde "E") 1)
                                              ((eq TabMde "F") 1)
                                          )
                                      )
                                      (cadr x)
                                  )
                                  2 
                                  (if (member TabMde (list  "E" "F")) 0 2);后缀零
                                );面积/尺寸
                                (caddr x);实数
                            )
                        )
                        TgtLst
                      )
              )
              (progn
                  (setq Tab (vla-addtable 
                              (vlax-get-property CurDoc (if (= 1 (getvar 'cvport)) 'paperspace 'modelspace))
                              (vlax-3D-point (trans TmpPT 1 0))
                              (+ 2 (length TgtLst));行数
                              (length TabType2);列数
                              (* 2.0 hgt);行高
                              (apply '+ (mapcar 'cdr TabType2)) ;列宽(后面要改)
                            )
                  )
                  (vla-put-stylename Tab StyNam);设置表格样式

                  (vla-settext Tab 0 0 TabType1);表头
                  (setq col 0)
                  (foreach XX TabType2
                      (vla-settext Tab 1 col (car XX))
                      (vla-SetColumnWidth Tab col (cdr XX))
                      (setq col (1+ col))
                  );标题和列宽
                
                  (if (>= (atoi (substr (ver) 13)) 2006)
                      (vla-put-RegenerateTableSuppressed Tab :vlax-true)
                  )
                
                  (setq row 2)
                  (foreach itm TgtLst 
                      (vla-settext Tab row (setq col 0) (K:AddZero4STR (rtos (1- row) 2 0) 2))
                      (cond
                        ((eq TabMde "B") 
                          (if (or
                                  (wcmatch (car itm) "USER*")
                                  (K:PatExists-P (car itm))
                              )
                              (progn
                                  (setq TmpNam (GG:MakeHatchBlk
                                                  (strcat "GG" (rtos TmpDimSca 2 (if (>= TmpDimSca 1.0) 0 1)) "-" (car itm))
                                                  (car itm)
                                                  (/ (caddr itm) TmpDimSca)
                                               )
                                  );创建块
                                  (while (> 0 (getvar 'cmdactive)) (command pause));等待前面的命令完成
                                  (GG:SetBlk2Tab Tab row (setq col (1+ col)) TmpNam)
                              )
                              (vla-settext Tab row (setq col (1+ col)) "图案缺失")
                          )
                        )
                        ((eq TabMde "E") 
                          (GG:SetBlk2Tab Tab row (setq col (1+ col)) (car itm))
                        )
                      );第二项(可能没有)
                      
                      (vla-settext Tab row (setq col (1+ col)) (car itm));第三项
                      (vla-settext Tab row (setq col (1+ col)) (cadr itm));第四项
                      (if (eq TabMde "F")
                          (vla-settext Tab row (setq col (1+ col)) "-");第四项
                      )
                      (setq row (1+ row))
                  )
                  (progn ;旋转表格
                      (setq Ang (angle '(0 0 0) (Vlax-Get Tab 'Direction)))
                      (setq UCS (angle '(0 0 0) (getvar 'UCSXDIR)))
                      (command 
                        "_.Rotate"
                        (vlax-vla-object->ename Tab) "" 
                        "_non" TmpPT "_R"
                        (angtos Ang (getvar 'AUNITS) 8)
                        (angtos UCS (getvar 'AUNITS) 8)
                      )
                  )
                
                  (if (>= (atoi (substr (ver) 13)) 2006)
                      (vla-put-RegenerateTableSuppressed Tab :vlax-false)
                  )
                  (while (> 0 (getvar 'cmdactive)) (command pause));等待前面的命令完成
                  (command "_.SCALE" (vlax-vla-object->ename Tab) "" 
                      "_non" TmpPT;块基点
                      TmpDimSca
                  );比例缩放
              )
              Nil ;退出循环
            )
            ((or ;字母D
                (not TmpPT)
                (and (eq (type TmpPT) 'STR)(eq (strcase TmpPT) "D"))
             )
              (progn
                (initget (+ 2 4));非零非负值
                (setq Global:AllDimSca (cond 
                            ((getreal (strcat "\n→请输入标注比例：<" (rtos TmpDimSca 2 2) ">")))
                            (TmpDimSca)
                          )
                )
              )
              (setq TmpDimSca Global:AllDimSca);更新值
              (setvar "DIMSCALE" Global:AllDimSca) ;CAD标注比例因子
              T ;继续循环
            )
            ((and (eq (type TmpPT) 'STR)(eq (strcase TmpPT) "E"));字母E
                (setq TgtLst 
                        (mapcar 
                          '(lambda (x) 
                              (list 
                                (if (eq TabMde "F")
                                    (strcat (car x) "x" (rtos (cadr x) 2 0) "个")
                                    (car x)
                                );名称/编号
                                (rtos 
                                  (if (eq TabUmm "1")
                                      (/ (cadr x)  
                                          (cond
                                              ((eq TabMde "A") 1000)
                                              ((eq TabMde "B") 1000000)
                                              ((eq TabMde "C") 1000000)
                                              ((eq TabMde "D") 1000000)
                                              ((eq TabMde "E") 1)
                                              ((eq TabMde "F") 1)
                                          )
                                      )
                                      (cadr x)
                                  )
                                  2 
                                  (if (eq TabMde "E") 0 2)
                                )
                              )
                            )
                          TgtLst
                        )
                )
                (if (or (eq TabMde "B") (eq TabMde "E"))
                    (setq TabType2 (list (car TabType2) (caddr TabType2) (cadddr TabType2)))
                )
                (setq StaNum 1)
                (setq FlieNam (vl-filename-mktemp "统计表" nil ".CSV"))
                (setq OpenFile (open FlieNam "w"))
                (Write-Line (K:Lst->STR (mapcar 'car TabType2) ",") OpenFile)
                (mapcar
                  '(lambda (XX)
                      (Write-Line 
                        (strcat 
                          (K:AddZero4STR (rtos StaNum 2 0) 2)
                          ","
                          (car XX)
                          ","
                          (cadr XX)
                        )
                        OpenFile
                      )
                      (setq StaNum (1+ StaNum))
                  )
                  TgtLst
                )
                (close OpenFile)
                (setq XX (vlax-get-or-create-object "Wscript.Shell"))
                (vlax-invoke XX'RUN FlieNam);(打开任意已经建立关联程序的文件)
                (vlax-release-object XX)
                Nil ;退出循环
            )
            ((and (eq (type TmpPT) 'STR)(eq (strcase TmpPT) "U"));字母U
                (setq Global:GCLUmm 
                    (cond 
                      ((eq Global:GCLUmm "1") "2")
                      ((eq Global:GCLUmm "2") "1")
                    )
                );1/2
                (setq TabUmm Global:GCLUmm)
                T ;继续循环
            )
            ((and (eq (type TmpPT) 'STR)(eq (strcase TmpPT) "N"));字母N
                (progn
                  (initget (+ 2 4));非零非负
                  (setq Global:TabNum  
                    (cond
                      ((getint (strcat   "\n→请输入附表序号：" "<" (rtos Global:TabNum 2 0) ">" )))
                      (Global:TabNum)
                    )
                  );附表序号
                )
                (setq TabNum Global:TabNum)
                T ;继续循环
            )
            (T
              (princ "\n——★★★ 请输入正确的关键词或 ESC退出！ ★★★——\n")
              T ;继续循环
            )
          )
        )
      )
  )
  ;根据所选模式统计工程量
  (defun GG:ExpData ( / WhFlag DataLst BadCNT SS i en obj TgtLen Hobj HBLst TgtArea TmpNam TgtNam TgtCen)
      (if
        (and
          (progn
            (initget (+ 2 4) "A B C D E F");非零非负值
            (setq Global:GCLMde 
                (cond 
                    ((getkword (strcat 
                                "→请选择模式:[A-长度图层/B-填充名称/C-填充颜色/D-面积图层/E-图块名称/F-编号数量]：" 
                                (cond 
                                  ((eq Global:GCLMde "A") "<A-长度图层>")
                                  ((eq Global:GCLMde "B") "<B-填充名称>")
                                  ((eq Global:GCLMde "C") "<C-填充颜色>")
                                  ((eq Global:GCLMde "D") "<D-面积图层>")
                                  ((eq Global:GCLMde "E") "<E-图块名称>")
                                  ((eq Global:GCLMde "F") "<F-编号数量>")
                                )
                              )
                      )
                    )
                    (Global:GCLMde)
                )
            )
          );获取模式
        )
        (progn
            (setq WhFlag T)
            (while
                (and
                    WhFlag
                    (princ 
                      (strcat 
                        "\n——★★★ 请"
                        (if (> Global:TabNum 1) "继续" "")
                        "选择非锁的<"
                        (cond 
                          ((eq Global:GCLMde "A") "直线+多段线+样条曲线+圆+圆弧+椭圆+椭圆弧")
                          ((eq Global:GCLMde "B") "填充图案")
                          ((eq Global:GCLMde "C") "填充图案")
                          ((eq Global:GCLMde "D") "填充图案+多段线、圆、椭圆")
                          ((eq Global:GCLMde "E") "图块")
                          ((eq Global:GCLMde "F") "CAD单行、CAD属性定义、天正单行")
                        )
                        "> ★★★——\n"
                      )
                    )
                )
                (if
                    (setq SS (ssget ":L"
                                (cond 
                                  ((eq Global:GCLMde "A") (list (cons 0 "LINE,ARC,*POLYLINE,SPLINE,CIRCLE,ELLIPSE")))
                                  ((eq Global:GCLMde "B") (list (cons 0 "HATCH")))
                                  ((eq Global:GCLMde "C") (list (cons 0 "HATCH")))
                                  ((eq Global:GCLMde "D") 
                                      (list 
                                        (cons -4 "<OR")
                                          (cons 0 "LWPOLYLINE")
                                          (cons 0 "POLYLINE")
                                          (cons -4 "<AND")
                                            (cons 0 "ELLIPSE")
                                            (cons 41 0);
                                            (cons 42 (* 2 pi));
                                          (cons -4 "AND>")
                                          (cons 0 "HATCH,CIRCLE")
                                        (cons -4 "OR>")
                                      )
                                  )
                                  ((eq Global:GCLMde "E") 
                                    (list (cons 0 "INSERT"))
                                  )
                                  ((eq Global:GCLMde "F") 
                                    (list (cons 0 "TEXT,ATTDEF,TCH_TEXT"))
                                  )
                                )
                            )
                    )
                    (progn
                        (setq DataLst Nil BadCNT 0)
                        (repeat (setq i (sslength SS)) 
                            (setq en (ssname SS (setq i (1- i)))
                                  obj (vlax-ename->vla-object en)
                            )
                              (cond 
                                ((eq Global:GCLMde "A") 
                                  (if (setq TgtLen (vlax-curve-getDistAtParam obj (vlax-curve-getendparam obj)))
                                      (setq DataLst 
                                            (GG:GetDataLst 
                                              (list (vla-get-Layer obj) TgtLen 1.0)
                                              DataLst
                                            )
                                      )
                                      
                                  )
                                )
                                ((eq Global:GCLMde "B") 
                                    (setq Hobj Nil HBLst Nil)
                                    (if 
                                        (or
                                            (not (vl-catch-all-error-p (setq TgtArea (vl-catch-all-apply 'vla-get-area (list obj)))));有面积
                                            (and
                                                (eq "AcDbHatch" (Vlax-Get obj 'ObjectName))
                                                (eq 1 (Vlax-Get obj 'NumberOfLoops))
                                                (eq 1 (length (setq HBLst (K:GetHatchBD en Nil))))
                                                (setq Hobj (vlax-ename->vla-object (car HBLst)))
                                                (not (vl-catch-all-error-p (setq TgtArea (vl-catch-all-apply 'vla-get-area (list Hobj)))));有面积
                                            );有面积
                                        )
                                        (progn
                                            (if (member (setq TmpNam (Vla-Get-PatternName obj)) (list "_U" "_USER"))
                                                (setq TmpNam (strcat 
                                                                  "USER"
                                                                  (rtos (Vla-Get-PatternScale obj) 2 0)
                                                                  (if (eq 1 (Cdr (Assoc 77 (Entget en))))
                                                                      "-D" "-N"
                                                                  )
                                                              )
                                                )
                                            )
                                            (setq DataLst 
                                                  (GG:GetDataLst 
                                                    (list TmpNam TgtArea (Vla-Get-PatternScale obj))
                                                    DataLst
                                                  )
                                            )
                                            (if HBLst 
                                                (foreach XX HBLst
                                                    (vla-Delete (vlax-ename->vla-object XX))
                                                )
                                            );删除填充边界
                                        )
                                        (progn 
                                            (vla-put-color obj 1);颜色变红
                                            (setq BadCNT (1+ BadCNT));统计无面积的对象数量
                                            (if HBLst 
                                                (foreach XX HBLst
                                                    (vla-Delete (vlax-ename->vla-object XX))
                                                )
                                            );删除填充边界
                                        )
                                    )
                                )
                                ((eq Global:GCLMde "C") 
                                    (setq Hobj Nil HBLst Nil)
                                    (if 
                                        (or
                                            (not (vl-catch-all-error-p (setq TgtArea (vl-catch-all-apply 'vla-get-area (list obj)))));有面积
                                            (and
                                                (eq "AcDbHatch" (Vlax-Get obj 'ObjectName))
                                                (eq 1 (Vlax-Get obj 'NumberOfLoops))
                                                (eq 1 (length (setq HBLst (K:GetHatchBD en Nil))))
                                                (setq Hobj (vlax-ename->vla-object (car HBLst)))
                                                (not (vl-catch-all-error-p (setq TgtArea (vl-catch-all-apply 'vla-get-area (list Hobj)))));有面积
                                            );填充对象有面积
                                        )
                                        (progn
                                            (setq DataLst 
                                                  (GG:GetDataLst 
                                                    (list (GG:GetHatchCol en) TgtArea 1.0)
                                                    DataLst
                                                  )
                                            )
                                            (if HBLst 
                                                (foreach XX HBLst
                                                    (vla-Delete (vlax-ename->vla-object XX))
                                                )
                                            );删除填充边界
                                        )
                                        (progn 
                                            (vla-put-color obj 1);颜色变红
                                            (setq BadCNT (1+ BadCNT));统计无面积的对象数量
                                            (if HBLst 
                                                (foreach XX HBLst
                                                    (vla-Delete (vlax-ename->vla-object XX))
                                                )
                                            );删除填充边界
                                        )
                                    )
                                )
                                ((eq Global:GCLMde "D") 
                                    (setq Hobj Nil HBLst Nil)
                                    (if 
                                        (or
                                          (and
                                              (wcmatch (Vlax-Get obj 'ObjectName) "*Polyline")
                                              (/= 0 (Vlax-Get obj 'Closed));闭合
                                              (not (vl-catch-all-error-p (setq TgtArea (vl-catch-all-apply 'vla-get-area (list obj)))));有面积
                                          );有面积的闭合多段线
                                          (and
                                              (not (wcmatch (Vlax-Get obj 'ObjectName) "*Polyline"))
                                              (not (vl-catch-all-error-p (setq TgtArea (vl-catch-all-apply 'vla-get-area (list obj)))));有面积
                                          );有面积的其它
                                          (and
                                            (eq "AcDbHatch" (Vlax-Get obj 'ObjectName))
                                            (eq 1 (Vlax-Get obj 'NumberOfLoops))
                                            (eq 1 (length (setq HBLst (K:GetHatchBD en Nil))))
                                            (setq Hobj (vlax-ename->vla-object (car HBLst)))
                                            (not (vl-catch-all-error-p (setq TgtArea (vl-catch-all-apply 'vla-get-area (list Hobj)))));有面积
                                          );无面积的填充
                                        )
                                        (progn
                                            (setq DataLst 
                                                  (GG:GetDataLst 
                                                    (list (vla-get-Layer obj) TgtArea 1.0)
                                                    DataLst
                                                  )
                                            )
                                            (if HBLst 
                                                (foreach XX HBLst
                                                    (vla-Delete (vlax-ename->vla-object XX))
                                                )
                                            );删除填充边界
                                        )
                                        (progn 
                                            (vla-put-color obj 1);颜色变红
                                            (setq BadCNT (1+ BadCNT));统计无面积的对象数量
                                            (if HBLst 
                                                (foreach XX HBLst
                                                    (vla-Delete (vlax-ename->vla-object XX))
                                                )
                                            );删除填充边界
                                        )
                                    )
                                )
                                ((eq Global:GCLMde "E") 
                                    (if
                                        (and
                                            (= "AcDbBlockReference" (vla-get-objectname obj));块
                                            (setq TgtNam (if (vlax-property-available-p obj 'effectivename) 
                                                          (vla-get-effectivename obj) ;动态块名
                                                          (vla-get-name obj) ;静态块名
                                                        )
                                            )
                                        )
                                        (setq DataLst 
                                              (GG:GetDataLst 
                                                (list TgtNam 1.0 1.0)
                                                DataLst
                                              )
                                        )
                                    )
                                )
                                ((eq Global:GCLMde "F") 
                                  (if (eq "ATTDEF" (Cdr(Assoc 0 (Entget en))))
                                      (setq TgtCen (Cdr(Assoc 2 (Entget en))))
                                      (setq TgtCen (Cdr(Assoc 1 (Entget en))))
                                  )
                                  (if (setq TgtCen (vl-list->string (vl-remove 32 (vl-string->list TgtCen))));移除空格
                                      (setq DataLst 
                                            (GG:GetDataLst 
                                              (list TgtCen 1.0 1.0)
                                              DataLst
                                            )
                                      )
                                      
                                  )
                                )
                              )
                        )
                        (if DataLst
                          (progn
                              (if
                                (and
                                  (eq Global:GCLUmm "1");毫米单位
                                  (<
                                    (/ 
                                        (apply 'max (mapcar 'cadr DataLst));最大值
                                        (cond
                                            ((eq Global:GCLMde "A") 1000)
                                            ((eq Global:GCLMde "B") 1000000)
                                            ((eq Global:GCLMde "C") 1000000)
                                            ((eq Global:GCLMde "D") 1000000)
                                            ((eq Global:GCLMde "E") 1)
                                            ((eq Global:GCLMde "F") 1)
                                        );毫米转米
                                    )
                                    0.01
                                  );小于
                                  (= 6 ;Yes
                                      (K:PopupWindows 
                                        "最大值小于0.01" 
                                        (strcat "\n是否将单位由毫米切换到米?")
                                        (+ 4 32 4096)
                                      )
                                  )
                                )
                                (setq Global:GCLUmm "2")
                              )
                              (if
                                  (or
                                    (= BadCNT 0)
                                    (and
                                        (> BadCNT 0)
                                        (= 6 ;Yes
                                            (K:PopupWindows 
                                              "继续插入统计表?" 
                                              (strcat "\n" (rtos BadCNT 2 0) " 个对象未查询到面积\n已变为红色且未计数\n")
                                              (+ 4 32 4096)
                                            )
                                        )
                                    )
                                  )
                                  (progn
                                      (GG:CreateTabSty "WorkTools" 5.0 4.0 0.0)
                                      (GG:CreateDataTab 
                                        "WorkTools"
                                        Global:GCLMde
                                        Global:GCLUmm
                                        (vl-sort DataLst '(lambda (a b) 
                                                            (if (eq Global:GCLMde "F")
                                                                (< (strcase (car a)) (strcase (car b)));字母
                                                                (if (eq (strcase (car a)) (strcase (car b)));
                                                                    (> (cadr a) (cadr b));数量大
                                                                    (<= (strcase (car a)) (strcase (car b)));字符大
                                                                )
                                                            )
                                                          )
                                        )
                                        Global:TabNum
                                      )
                                      (setq Global:TabNum (1+ Global:TabNum))
                                  )
                              )
                          )
                          (alert (strcat "※未提取到任何数据，程序退出！"))
                        )
                    )
                    (progn
                        (princ (strcat "\n——★★★ 未选择对象，程序退出！ ★★★——\n"))
                        (setq WhFlag Nil)
                    )
                )
            )
        )
        (princ (strcat "\n——★★★ 未选择模式，程序退出！ ★★★——\n"))
      )
  )
  ;面积或模式
  (defun GG:GetUCSorMde (/ K:GetClsUcsLst UCSLst TmpPT TmpPT2 TgtEn AA)
    ;获取撑开的多边形UCS点表
    (defun K:GetClsUcsLst (UCSPT / PTLst TgtPT TmpLst)
        (defun *error* (x)  ;出错函数
          (redraw)
        )
        (if (car (setq PTLst (list UCSPT
                              ;(getpoint "\n→请指定起点或空格退出")
                            ))) 
            (progn
              (while 
                (setq TgtPT 
                    (if (>= (length PTLst) 2) ;至少两个点
                        (if (>= (length PTLst) 3) ;三个点
                            (progn 
                              (initget "U")
                              (getpoint (car PTLst) "\n→请指定下一点或空格结束 [撤回(U)]: ")
                            )
                            (progn 
                              (initget 1 "U")
                              (getpoint (car PTLst) "\n→请指定下一点或 [撤回(U)]:")
                            )
                        )
                        (progn 
                          (initget 1 "S");非空
                          (getpoint (car PTLst)"\n→请指定下一点")
                        )
                    )
                );第二个点
                (redraw)
                (cond 
                    ((and (eq (type TgtPT) 'STR) (eq TgtPT "U"))
                        (setq PTLst (cdr PTLst))
                    )
                    ((eq (type TgtPT) 'LIST)
                        (setq PTLst (cons TgtPT PTLst))
                    )
                ) ;根据关键词返回坐标点
                (if (>= (length PTLst) 3);多边形
                    (progn
                        (setq TmpLst (cons (Last PTLst) PTLst));闭合坐标
                        (mapcar '(lambda (a b) (grdraw a b 1 -1)) TmpLst (cdr TmpLst)) ;画线
                    )
                    (mapcar '(lambda (a b) (grdraw a b 1 -1)) PTLst (cdr PTLst)) ;画线
                )
              ) ;下一点OR撤回
              (redraw)
            )
        )
        (if (>= (length PTLst) 3) PTLst)
    )
    (setq UCSLst Nil)
    (while ;get*
      (progn 
        (initget (+ 2 4) "O A S U T") ;非零非负关键词
        (setq TmpPT (getpoint (strcat 
                                "\n→请指定起点或空格模式：[对象(O)"
                                (if Global:GCLAdd "/增加面积(A)" "/减少面积(A)" ) 
                                "/比例(S)_" (rtos TmpDimSca 2 1)
                                (if (eq Global:GCLUmm "1") "/当前单位:毫米(U)" "/当前单位:米(U)")
                                "/标注面积(T)]"
                              )
                    )
        )
        (cond 
          ((and TmpPT (eq (type TmpPT) 'LIST));指定了点
            (if (setq TmpPT2 (getcorner TmpPT "\n→请指定矩形角点或空格多边形：")) 
                (setq UCSLst
                    (list
                        TmpPT
                        (list (car TmpPT) (cadr TmpPT2) 0.0)
                        TmpPT2
                        (list (car TmpPT2) (cadr TmpPT) 0.0)
                    )
                )
                (setq UCSLst (K:GetClsUcsLst TmpPT))
            )
            (if
                (and
                    UCSLst
                    (setq TgtEn
                          (entmakeX 
                            (append 
                              (list 
                                (cons 0 "LWPOLYLINE")
                                (cons 100 "AcDbEntity")
                                (cons 100 "AcDbPolyline")
                                (cons 90 (length UCSLst))
                                (cons 70 1);闭合
                              )
                              (mapcar 
                                '(lambda (PT) (cons 10 (trans PT 1 0))) 
                                UCSLst
                              )
                            )
                          )
                    )
                    (not 
                      (vl-catch-all-error-p 
                        (setq AA (vl-catch-all-apply 'vla-get-area (list (vlax-ename->vla-object TgtEn))))
                      )
                    );有面积
                )
                (progn
                    (setq TgtArea ((if Global:GCLAdd + -)
                                    TgtArea 
                                    (if (eq Global:GCLUmm "1") (/ AA 1000000) AA)
                                  )
                    )
                    (if (< TgtArea 0.0) (setq TgtArea 0.0))
                    (princ (strcat "\n——★★★ 当前单位:"
                            (if (eq Global:GCLUmm "1") "毫米" "米")
                            ", 面积累积为<" (rtos TgtArea 2 2) ">平方米！ ★★★——\n")
                    )
                    (princ)
                    (vla-Delete (vlax-ename->vla-object TgtEn));删除多边形
                )
            )
            Nil ;退出循环
          )
          ((and (eq (type TmpPT) 'STR)(eq (strcase TmpPT) "O"));字母O
            (if
                (and
                    (setq TgtEn (car (nentsel)))
                    (not 
                      (vl-catch-all-error-p 
                        (setq AA (vl-catch-all-apply 'vla-get-area (list (vlax-ename->vla-object TgtEn))))
                      )
                    );有面积
                )
                (progn
                    (setq TgtArea ((if Global:GCLAdd + -)
                                    TgtArea 
                                    (if (eq Global:GCLUmm "1") (/ AA 1000000) AA)
                                  )
                    )
                    (if (< TgtArea 0.0) (setq TgtArea 0.0))
                    (princ (strcat "\n——★★★ 当前单位:"
                            (if (eq Global:GCLUmm "1") "毫米" "米")
                            ", 面积累积为<" (rtos TgtArea 2 2) ">平方米！ ★★★——\n")
                    )
                    (princ)
                )
            )
            (if (not AA)
                (princ (strcat "\n——★★★ 所选对象无面积！ ★★★——\n"))
            )
            T ;继续循环
          )
          ((and (eq (type TmpPT) 'STR)(eq (strcase TmpPT) "A"));字母A
            (setq Global:GCLAdd (not Global:GCLAdd))
            T ;继续循环
          )
          ((and (eq (type TmpPT) 'STR)(eq (strcase TmpPT) "S"));字母S
              (progn
                (initget (+ 2 4));非零非负值
                (setq Global:AllDimSca (cond 
                            ((getreal (strcat "\n→请输入标注比例：<" (rtos TmpDimSca 2 2) ">")))
                            (TmpDimSca)
                          )
                )
              )
              (setq TmpDimSca Global:AllDimSca);更新值
              (setvar "DIMSCALE" Global:AllDimSca) ;CAD标注比例因子
              T ;继续循环
          )
          ((and (eq (type TmpPT) 'STR)(eq (strcase TmpPT) "U"));字母U
            (setq Global:GCLUmm 
                (cond 
                  ((eq Global:GCLUmm "1") "2")
                  ((eq Global:GCLUmm "2") "1")
                )
            );1/2
            T ;继续循环
          )
          ((and (eq (type TmpPT) 'STR)(eq (strcase TmpPT) "T"));字母T
            (if (setq TmpPT2 (getpoint "\n→请指定文字插入点"))
                (entmakeX
                  (list 
                      (cons 0 "TEXT")
                      (cons 62 1);红色
                      (cons 10 (trans TmpPT2 1 0))
                      (cons 11 (trans TmpPT2 1 0))
                      (cons 72 1);水平居中
                      (cons 73 2);垂直居中
                      (cons 1 (strcat (rtos TgtArea 2 2) "平方米"));面积
                      (cons 40 (* TmpDimSca 3.5));字高
                      (cons 50 (- (* 2 pi) (getvar "viewtwist")));文字旋转始终水平视图
                  ) 
                );单行提示文字
            )
            T ;继续循环
          )
          (T
            (GG:ExpData)
            Nil ;退出循环
          )
        )
      )
    )
    UCSLst
  )
)
(defun C:AA (/ *error* CurDoc *Old_SysVar* DataLst BadCNT WhFlag SS i en obj Hobj HBLst TgtLen TgtArea TgtCen TgtNam TmpNam) 
  (setq CurDoc (vla-get-activedocument (vlax-get-acad-object)))
  (defun *error* (x)  ;出错函数
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
            '(lambda (a / b) 
              (if (setq b (getvar (car a)))
                  (progn 
                    (vl-catch-all-apply 'setvar a)
                    (list (car a) b)
                  )
              )
            )
            (list 
              (list "DIMZIN" 0);保留前导和后续的零
              (list "CMDECHO" 0) ;关闭回显
            )
          )
      );记录参数
      (if (not Global:GCLMde) (setq Global:GCLMde "B"));模式:ABCD
      (if (not Global:GCLUmm) (setq Global:GCLUmm "1"));当前单位:1毫米,2米
      (setq Global:AllDimSca
          (if (and (not Global:AllDimSca)  (equal (getvar "DIMSCALE") 1.0 1e-6))
              (setvar "DIMSCALE" 50)
              (getvar "DIMSCALE")
          )
      );默认标注比例
      (setq TmpDimSca 
              (if (and (eq (getvar "TILEMODE") 0)(eq (getvar "CVPORT") 1));布局空间
                  1 
                  Global:AllDimSca
              )
      )
      
      ;默认比例(天正存在取天正)
      (if (not Global:TabNum) (setq Global:TabNum 1));附表数量
    )
    (if (eq 4 (logand 4 (cdr (assoc 70 (tblsearch "LAYER" (getvar "CLAYER"))))))
        (alert (strcat "※当前图层已锁定, 无法运行程序！"))
        (if (null (last (ssgetfirst)));没有预选
            (progn
              (setq TgtArea 0.0)
              (setq Global:GCLAdd T);面积增减
              (while (GG:GetUCSorMde))
            )
            (GG:ExpData)
        )

    )
    (command "redraw");清空一行
    (if *Old_SysVar* (foreach xx *Old_SysVar* (apply 'setvar xx)));参数恢复
  (vla-endundomark CurDoc) ;结束编组
  (princ)
)


(if (not (getenv "K\\ToolsIsExit"))
    (princ "\n——★★★ 统计工程量由Kucha开发, 调用命令: GG ★★★——")
)(princ)