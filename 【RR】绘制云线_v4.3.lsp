(if (null vlax-dump-object) (vl-load-com));将Visual LISP扩展功能加载到 AutoLISP

;*MkVarLst*
;Global:RvDyn ;1静态云线,2动态云线
;Global:RvLay ;1默认层,2当前层
;Global:RvTXT ;1标注文字,2不标文字
;Global:RvSLa ;1字同云线图层,2字单独一个层层
;Global:RvMde ;1修改,2批注,3检查
;Global:RvPre ;1时间内容,2时间人员,3人员内容,4人员时间内容,5仅内容,6仅时间,7仅人员,8自定义
;Global:RvUSE ;8自定义内容
;Global:RvDIM ;默认比例(在模型空间且天正存在时忽略该值)


;Global:ArLen ;默认弧长
;Global:SVMde ;Y/N框叉后视口是否关闭显示

;TmpCol ;图层颜色
;TXTCol ;文字颜色
;TmpDIM ;标注比例
;TmpSCV ;增减倍数

(defun C:RR (/ CurDoc *Old_SysVar* *MkVarLst* SS TgtSS TmpDIM GetDIM LayLst GreyLay LayFrz RvLayObj 
                Code Key TgtPT HasGetRv RvEn TmpArLen NewLst e0 NewEn EnType RvTipEn StaPT DiaPT SSVP i obj DGrey
            )
    (setq CurDoc (vla-get-activedocument (vlax-get-acad-Object)))
    (defun *error* (msg);定义出错函数
      (redraw)
      (if RvTipEn (vla-delete (vlax-ename->vla-object RvTipEn)));删除临时文字
      (K:SetGetData T "K\\RRSysNam" *MkVarLst*);用全局更新系统和黑板
      (if LayFrz (setq Global:RvLay "1"));恢复默认图层
      (if *Old_SysVar* (foreach xx *Old_SysVar* (apply 'setvar xx)));参数恢复
      (vla-endundomark CurDoc) ;结束编组
    )
    (progn ;云线函数
      ;获取当前色的ACI近似色
      (defun Rv:Cecolor4ACI (/ LayObj CurCol AciCol LayLck TmpEn)
          (setq LayObj (vlax-ename->vla-object (tblobjname "LAYER" (getvar "CLAYER"))));当前层
          (setq CurCol (getvar "CECOLOR"))
          (cond
              ((<= 1 (atoi CurCol) 255)(setq AciCol (atoi CurCol)));1~255
              ((= "BYBLOCK" CurCol) (setq AciCol 7));随块0
              ((= "BYLAYER" CurCol) (setq AciCol (vla-get-Color LayObj)));随层取层色
              (T 
                  (setq LayLck Nil)
                  (if (eq (vla-get-lock LayObj) :vlax-true);锁定了
                      (progn 
                        (setq LayLck T)
                        (vla-put-lock LayObj :vlax-false);解锁
                      )
                  );临时解锁当前层
                  (setq TmpEn (entmakeX (list '(0 . "POINT") (cons 10 '(0.0 0.0 0.0)))));创建临时实体
                  (setq AciCol (cdr (assoc 62 (entget TmpEn))))
                  (if TmpEn (vla-Delete (vlax-ename->vla-object TmpEn)));删除临时实体
                  (if LayLck (vla-put-lock LayObj :vlax-false));重新锁定当前层
              );RGB或其它
          )
          AciCol
      )
      ;根据日期标注随机改变颜色
      (defun Rv:RandCol4Dat (TgtSS RandFlag / K:RandVar EnLst ColLst XX)
        (progn
            ;给定范围内的伪随机整数@LeeMac
            (defun K:RandVar ( a b / LM:rand)
                ;0~1的随机数@LeeMac
                (defun LM:rand ( / a c m )
                    (setq m   4294967296.0
                          a   1664525.0
                          c   1013904223.0
                          $xn (rem (+ c (* a (cond ($xn) ((getvar 'date))))) m)
                    )
                    (/ $xn m)
                )
                (+ (min a b) (fix (* (LM:rand) (1+ (abs (- a b))))))
            )
        )
        (if TgtSS
            (progn
                (setq EnLst (K:SS->EntLst TgtSS))
                (setq ColLst Nil)
                (foreach XX EnLst
                    (setq RvDat (Last (mapcar 'cdr (cdadr  (assoc -3 (entget XX '("RvData")))))))
                    (if (not (member RvDat ColLst))
                        (setq ColLst (cons RvDat ColLst))
                    )
                );收集日期
                (setq ColLst
                  (mapcar
                    '(lambda (XX)
                        (cons 
                          XX 
                          (if RandFlag
                              (Rv:RandVar 0 (- 255 (atof (Rv:GetHMCol XX))))
                              (atof (Rv:GetHMCol XX))
                          )
                          
                        )
                    )
                      ColLst
                  )
                );颜色及日期
                (foreach XX EnLst
                    (setq RvDat (Last (mapcar 'cdr (cdadr  (assoc -3 (entget XX '("RvData")))))))
                    (vla-put-color (vlax-ename->vla-object XX) (Cdr (Assoc RvDat ColLst)))
                );修改颜色
            )
        )
      )
      ;获取月日的上中下旬对应的颜色
      (defun Rv:GetHMCol (TimeSTR / TimLst Flag)
        (setq TimLst
          (mapcar 'distof 
            (if (vl-string-search "/" TimeSTR)
                (K:STR->LST TimeSTR "/")
                (list 
                    (substr TimeSTR 1 4)
                    (substr TimeSTR 5 2)
                    (substr TimeSTR 7 2)
                )
            )
          )
        );拆分字符串转实数
        (setq Flag (equal (rem (nth 1 TimLst) 2) 0.0 0.0001))
        (cond 
            ((< 0 (nth 2 TimLst) 11)  (strcat (rtos (+ (* 2 (- (last TimLst) 0 )) 2) 2 0) (if Flag "1" "8")));上旬
            ((< 10 (nth 2 TimLst) 21) (strcat (rtos (+ (* 2 (- (last TimLst) 10)) 2) 2 0) (if Flag "5" "4" )));中旬
            ((< 20 (nth 2 TimLst) 32) (strcat (rtos (+ (* 2 (- (last TimLst) 20)) 2) 2 0) (if Flag "9" "0")));下旬
        );结果
      )
      ;给定范围内的伪随机整数@LeeMac
      (defun Rv:RandVar ( a b / LM:rand)
          ;0~1的随机数@LeeMac
          (defun LM:rand ( / a c m )
              (setq m   4294967296.0
                    a   1664525.0
                    c   1013904223.0
                    $xn (rem (+ c (* a (cond ($xn) ((getvar 'date))))) m)
              )
              (/ $xn m)
          )
          (+ (min a b) (fix (* (LM:rand) (1+ (abs (- a b))))))
      )
      ;随机色子功能
      (defun Rv:ChgRandCol (TgtSS / Code Key XX i TmpEn)
        (if (and
              TgtSS
              (setq TgtSS
                (ssget "P"
                  '((-4 . "<and")
                      (0 . "LWPOLYLINE")
                      (-3 ("RvData"))
                        (-4 . "<not")
                        (-3 ("MkBox"))
                        (-4 . "not>")
                    (-4 . "and>")
                  )
                );仅选云线
              )
            )
            (while ;Grread
              (progn
                (princ (strcat "\n→空格变色或ESC退出或 [指定色(C)/重置色(R)]"))
                (while (and (setq Code (grread T (+ 1 4 8) 2)) (eq (car Code) 5)))
                (setq Key (cadr Code))
                (cond
                  ((member Key (list 13 32));回车或空格
                    (Rv:RandCol4Dat TgtSS T);随机颜色
                    (princ "\n——★★★ 颜色已根据云线日期随机变化,空格继续！ ★★★——\n")(princ)
                    T ;继续循环
                  )
                  ((member Key (list 67 (+ 67 32)));字母C
                    (if (setq XX (rtos (acad_colordlg 1 Nil) 2 0))
                        (repeat (setq i (sslength TgtSS)) 
                            (setq TmpEn (ssname TgtSS (setq i (1- i))))
                            (vla-put-color (vlax-ename->vla-object TmpEn) XX)
                        )
                    )(princ)
                    (princ "\n——★★★ 颜色已调整为所选颜色！ ★★★——\n")(princ)
                    Nil ;退出循环
                  )
                  ((member Key (list 82 (+ 82 32)));字母R
                    (Rv:RandCol4Dat TgtSS Nil);随机颜色
                    (princ "\n——★★★ 颜色已调整为标注日期对应的颜色！ ★★★——\n")(princ)
                    Nil ;退出循环
                  )
                  (T 
                    (princ "\n——★★★ 请输入正确的关键词或 ESC退出！ ★★★——\n")
                    T ;继续循环
                  )
                )
              )
            )
            (alert "所选对象不含云线！")
            ;(princ "\n——★★★ 所选对象不含云线！ ★★★——\n")
        )
      )
      ;赋予对象RvData
      (defun Rv:PutRvData (TgtEn)
          (regapp "RvData");为扩展数据注册程序名
          (entmod 
            (cons 
              (list 
                -3
                (list 
                  "RvData"
                  (cons 1000 (getenv "USERNAME"));人员
                  (cons 1000 (menucmd "M=$(edtime,$(getvar,date),YYYY/MO/DD)"));时间
                )
              )
              (entget TgtEn)
            )
          )
      )
      ;根据实体UCS边界框的短边推荐弧长
      (defun Rv:RecSugArLen (TgtEn / Box MinPt MaxPt Width SugArLen) 
        (setq Box (K:GetUCSBox TgtEn))
        (setq MinPt (car Box)
              MaxPt (cadr Box)
        )
        (setq Width (min 
                      (abs (- (car MaxPt) (car MinPt)))
                      (abs (- (cadr MaxPt) (cadr MinPt)))
                    )
        );XY取较小的那个
        (setq SugArLen ;设置推荐弧长
            (cond 
              ((< Width 2) Width)
              ((and (>= Width 2) (< Width 10)) 1)
              ((and (>= Width 10) (< Width 30)) 3)
              ((and (>= Width 30) (< Width 300)) 5)
              ((and (>= Width 300) (< Width 600)) 10)
              ((>= Width 600) (fix (/ Width 20)))
            )
        )
        SugArLen
      )
      ;点表生成多段线
      (defun Rv:MakeLWPOLYLINE (WCS Clsd PTLst / PT) 
        (entmakeX 
          (append 
            (list 
              (cons 0 "LWPOLYLINE")
              (cons 100 "AcDbEntity")
              (cons 100 "AcDbPolyline")
              (cons 90 (length PTLst))
            )
            (if Clsd (list (cons 70 1)))
            (mapcar '(lambda (PT) 
                      (cons 10 
                        (if WCS PT (trans PT 1 0))
                      )
                    ) 
                    PTLst
            )
          )
        )
      )
      ;获取直线+轻重多段线的顶点表
      (defun Rv:GetTgtVxtLst (obj / K:LstGroup4Num)
          (if (eq 'ENAME (type obj))(setq obj (vlax-ename->vla-object obj)))
          ;按给定Num对列表元素进行分组
          (defun K:LstGroup4Num (Lst Num / i NewLst Result) 
            (while Lst 
              (setq i Num)
              (while (and Lst (< 0 i)) 
                (setq NewLst (cons (car Lst) NewLst)
                      Lst    (cdr Lst)
                      i      (1- i)
                )
              )
              (setq Result (cons (reverse NewLst) Result)
                    NewLst nil
              )
            )
            (reverse Result)
          )
          (setq VxtLst Nil)
          (cond
            ((eq (vlax-get obj "ObjectName") "AcDbLine");直线
              (setq VxtLst (list (Vlax-Get obj 'StartPoint)(Vlax-Get obj 'EndPoint)))
            )
            ((eq (vlax-get obj "ObjectName") "AcDbPolyline");轻多段线
              (setq VxtLst (K:LstGroup4Num (Vlax-Get obj 'Coordinates) 2));多段线顶点坐标(不含Z)
            )
            ((eq (vlax-get obj "ObjectName") "AcDb2dPolyline");重多段线
              (setq VxtLst (K:LstGroup4Num (Vlax-Get obj 'Coordinates) 3));多段线顶点坐标(含Z)
            )
          )
          (if VxtLst (mapcar '(lambda (PT) (trans PT 0 1)) VxtLst))
      )
      ;点表偏移多段线
      (defun Rv:DynOffUCSLst (UCSLst Dst4PL / K:INPLst i StaPT NxtPT Ang FstLst SecLst TmpLst)
            ;求偏移后的UCS每段的交点成UCS点表
            (defun K:INPLst (TmpLst / i SL EL InP RtnLst)
                (setq i 0)
                (while (< i (1- (length TmpLst)))
                    (setq SL (nth i TmpLst)
                          EL (nth (setq i (1+ i)) TmpLst)
                    )
                    (if (setq InP (inters (car SL) (cadr SL) (car EL) (cadr EL) nil));无限长求交点
                        (setq RtnLst (cons InP RtnLst))
                    )
                )
                (setq RtnLst (append (list (car (car TmpLst))) (reverse RtnLst) (list (cadr (Last TmpLst)))))
            )
            (setq FstLst Nil SecLst Nil)
            (setq i 0);初始化
            (while (< i (1- (length UCSLst)));差两个？
                (progn
                    (setq StaPT (nth i UCSLst);UCS
                          NxtPT (nth (setq i (1+ i)) UCSLst);UCS
                    )
                    (if (eq i 1)
                          (setq StaPT (polar NxtPT (angle NxtPT StaPT) (+ (distance NxtPT StaPT) Dst4PL)))
                    );第一个
                    (if (eq i (1- (length UCSLst)))
                        (setq NxtPT (polar StaPT (angle StaPT NxtPT) (+ (distance StaPT NxtPT) Dst4PL)))
                    );最后一个
                    (setq Ang (- (angle StaPT NxtPT) (* 0.5 pi)))
                    (while (minusp Ang)(setq Ang (+ Ang (* 2 pi))))
                    (setq FstLst (cons (list (polar StaPT Ang (+ 0 Dst4PL)) (polar NxtPT Ang (+ 0 Dst4PL))) FstLst)
                          SecLst (cons (list (polar StaPT Ang (- 0 Dst4PL)) (polar NxtPT Ang (- 0 Dst4PL))) SecLst)
                    )
                )
            );分段两侧偏移
            (setq TmpLst (append (K:INPLst (reverse FstLst)) (reverse (K:INPLst (reverse SecLst)))))
            TmpLst 
      )
      ;根据UCS折线点表生成两侧偏移的折线
      (defun Rv:GetOFFPL (UCSLst TgtCol / StaPt Code TmpLst i Key EntNam)
        (if (and UCSLst (>= (length UCSLst) 2))
              (progn
                  (setq StaPt (Last UCSLst));UCS
                  (while 
                    (progn
                      (princ "\n→请指定偏移距离<或空格>: ")
                      (while (and (setq Code (grread T (+ 1 4 8))) (eq (car Code) 5)) 
                          (redraw)
                          (grdraw StaPt (cadr Code) TgtCol);长度线
                          (setq TmpLst (Rv:DynOffUCSLst UCSLst (* 0.5 (distance StaPt (cadr Code)))))
                          (setq i 0);初始化
                          (while (< i (length TmpLst))
                              (if (= (setq i (1+ i)) (length TmpLst));最后一个
                                  (grdraw (Last TmpLst) (car TmpLst) TgtCol)
                                  (grdraw (nth (1- i) TmpLst) (nth i TmpLst) TgtCol)
                              )
                          );显示线
                      );显示预览
                      (setq Key (cadr Code))
                      (cond
                        ((and (eq (car Code) 3) (eq (type Key) 'LIST));点选
                            (redraw)
                            (setq EntNam (Rv:MakeLWPOLYLINE Nil T (Rv:DynOffUCSLst UCSLst (* 0.5 (distance StaPt (cadr Code))))))
                            Nil ;退出循环
                        )
                        ((equal Code '(2 32));空格
                          (redraw)
                          (setq EntNam (Rv:MakeLWPOLYLINE Nil T  (Rv:DynOffUCSLst UCSLst (* 0.5 (distance StaPt (cadr (grread '(2 32))))))))
                          Nil ;退出循环
                        )
                        (T Nil)
                      )
                    )
                  )
                  EntNam
              )
        )
      )
      ;绘制动态多双偏移多段线+矩形+封闭的多边形+圆
      (defun Rv:DrawDynRvEn (UCSPT TgtCol / MidFlag Ang Code TgtKey PTLst EntNam K:DynDrawRec K:DynDrawPoly) 
        (progn ;基础函数
          ;选取多个UCS点用于生成多段线
          (defun K:GetUCSPTLst (TgtCol / UCSLst TgtPT) 
              (setq UCSLst Nil)
              (if (car (setq UCSLst (list (getpoint "\n→请指定折线起点:")))) 
                  (while 
                    (setq TgtPT (if (>= (length UCSLst) 2)  ;至少两个点
                                  (progn 
                                    (initget "U")
                                    (getpoint (car UCSLst) "\n→请指定下一点或空格结束[撤回(U)]: ")
                                  )
                                  (getpoint (car UCSLst) "\n→请指定下一点或空格结束:")
                                )
                    )
                    (redraw)
                    (mapcar 
                      '(lambda (a b) (grdraw a b TgtCol 1))
                      (setq UCSLst (if (eq TgtPT "U") 
                                    (cdr UCSLst)
                                    (cons TgtPT UCSLst)
                                  )
                      )
                      (cdr UCSLst)
                    )
                  )
              )
              (princ)(redraw)
              (cond ((>= (length UCSLst) 2) (reverse UCSLst)))
          )
          ;动态绘制矩形:Flag为T时，表示StaPT是矩形中心点。返回四个角点坐标
          (defun K:DynDrawRec (MidFlag StaPT DiaPT Ang / TmpDst TmpAng) 
              (if MidFlag
                (setq StaPT (mapcar '- StaPt (mapcar '- DiaPT StaPt)))
              )
              (setq TmpDst (distance StaPT DiaPT)
                    TmpAng (- (angle StaPT DiaPT) Ang)
              )
              (list 
                StaPT
                (polar StaPT Ang (* TmpDst (Cos TmpAng)))
                DiaPT
                (polar StaPT (+ Ang (/ pi 2)) (* TmpDst (Sin TmpAng)))
              )
          )
          ;动态绘制闭合多边形
          (defun K:DynDrawPoly (StaPt TgtCol / K:GetPTLst PTLst EntNam) 
            ;收集UCS坐标点
            (defun K:GetPTLst (StaPt TgtCol / Code PTLst) 
              (setq PTLst (list StaPt))
              (princ "\n→请继续指定点<空格退出>: ")
              (while 
                (setq Code 
                    (progn 
                      (while (and (setq Code (grread T (+ 1 4 8)))(eq (car Code) 5)) 
                        (redraw)
                        (mapcar 
                          '(lambda (P1 P2) 
                              (grdraw P1 P2 TgtCol)
                            )
                          (cons (cadr Code) PTLst)
                          (append PTLst (cdr Code))
                        )
                      )
                      (if (listp (cadr Code))
                        (cadr Code)
                      )
                    )
                )
                (setq PTLst (cons Code PTLst))
              )
              (redraw)
              PTLst
            )
            (if (setq PTLst (K:GetPTLst StaPt TgtCol))
                (setq EntNam (Rv:MakeLWPOLYLINE Nil T PTLst))
            )
            EntNam
          )
          ;动态绘制圆@Kucha
          (defun K:DynDrawCircle (StaPt TgtCol / K:GrvecsCircle Code TgtKey EntNam) 
            ;grdraw绘制近似圆@LEEMAC
            (defun K:GrvecsCircle (Cen Rad TgtCol / ang inc) 
              (setq inc (/ (+ pi pi) 24.0)
                    ang 0.0
              )
              (repeat 24 (grdraw (polar Cen ang Rad) (polar Cen (setq ang (+ ang inc)) Rad) TgtCol))
            )
            (while 
              (progn
                (princ "\n→请指定半径<空格退出>: ")
                (while (and (setq Code (grread T (+ 1 4 8))) (eq (car Code) 5)) 
                    (redraw)(K:GrvecsCircle StaPt (distance StaPt (cadr Code)) TgtCol)
                );显示预览
                (setq TgtKey (cadr Code))
                (cond
                  ((eq (car Code) 3);点选
                      (redraw)
                      (setq EntNam (entmakeX (list '(0 . "CIRCLE") (cons 10 (trans StaPt 1 0)) (cons 40 (distance StaPt (cadr Code))))))
                      Nil ;退出循环
                  )
                  (T Nil)
                )
              )
            )
            EntNam
          )
        )
        (setq Ang 0.0);启动时清空角度
        (setq MidFlag Nil);StaPT默认为矩形角点
        (while 
          (progn
            (princ 
                (strcat 
                    "\n→请指定矩形对角点或空格画折线 [折线(L)/圆(C)/多边形(P)/旋转(R)"
                    (if (eq MidFlag Nil) "/中心绘制(M)" "/角点绘制(M)")
                    "]"
                )
            )
            (while (and (setq Code (grread T (+ 1 4 8))) (eq (car Code) 5)) 
                (redraw)
                (setq PTLst (K:DynDrawRec MidFlag UCSPT (cadr Code) Ang))
                (mapcar '(lambda (a b) (grdraw a b TgtCol)) (cons (last PTLst) PTLst) PTLst)
            );显示预览
            (setq TgtKey (cadr Code))
            (cond
              ((eq (car Code) 3);点选
                  (setq EntNam (Rv:MakeLWPOLYLINE Nil T (K:DynDrawRec MidFlag UCSPT (cadr Code) Ang)))
                  Nil ;退出循环
              )
              ((or (eq TgtKey 32)(eq TgtKey 76)(eq TgtKey (+ 76 32)));空格或字母L
                  (redraw)
                  (setq EntNam (Rv:GetOFFPL (K:GetUCSPTLst TgtCol) TgtCol))
                  Nil ;退出循环
              )
              ((or (eq TgtKey 67)(eq TgtKey (+ 67 32)));字母C
                  (redraw)
                  (setq EntNam (K:DynDrawCircle (getpoint "\n→请选择圆心点:") TgtCol))
                  Nil ;退出循环
              )
              ((or (eq TgtKey 80)(eq TgtKey (+ 80 32)));字母P
                  (redraw)
                  (setq EntNam (K:DynDrawPoly UCSPT TgtCol))
                  Nil ;退出循环
              )
              ((or (eq TgtKey 82)(eq TgtKey (+ 82 32)));字母R
                  (redraw)
                  (setq Ang (getangle UCSPT "\n→指定矩形旋转角:"))
                  T ;继续循环
              )
              ((or (eq TgtKey 77)(eq TgtKey (+ 77 32)));字母M
                  (redraw)
                  (setq MidFlag (not MidFlag))
                  T ;继续循环
              )
              (T 
                  (princ "\n——★★★ 请输入正确的关键词或 ESC退出！ ★★★——\n")
                  T ;继续循环
              )
            )
          )
        )
        (redraw)
        EntNam
      )
      ;绘制动态云线,并返回弧长值和云线对象名
      (defun Rv:DynCloudLine (TgtEn TgtPT / OriEnt Flag Code Key Dist Dleta ArLen)
        (setq OriEnt (entget TgtEn))
        (setq Dist (Rv:RecSugArLen TgtEn))
        (setq Flag nil)
        (while (and (setq Code (grread T (+ 1 4 8))) (eq (car Code) 5))
          (setq Key (cadr Code))
          (if (not TgtPT)
            (setq TgtPT (polar Key pi Dist))
            (progn
                (if (eq Flag T)
                    (progn 
                        (vla-delete (vlax-ename->vla-object TgtEn));删除云线
                        (setq TgtEn (entmakeX OriEnt));生成新矩形
                    )
                )
                (redraw)
                (grdraw TgtPT Key -1);绘制直线
                (setq Dleta (- (distance TgtPT Key) Dist))
                (setq ArLen (+ Dist (/ Dleta 10)))
                (while (> (getvar "CMDACTIVE") 0) (command PAUSE));等待前面的命令完成
                (command "_.REVCLOUD" "A" ArLen ArLen "O" TgtEn "N");创建云线
                (setq TgtEn (entlast))
                (setq Flag T)
            )
          )
        )
        ;(setq Global:ArLen ArLen);更新最大弧长的全局变量
        (redraw)
        (list TgtEn ArLen)
      )
      ;创建云线文字标注
      (defun Rv:CreatRvTXT (TgtCol TgtDIM EntLst / K:DelSame K:GetEndPTLst K:GetMdeSTR K:GetTgtSTR TipHNam TipTime TipMSTR TmpDIM TmpSTR UseFlag ObjLst Code StaPT PtLst MTEN ) 
          (progn ;基础函数
              ;表根据容差去重@LEEMAC
              (defun K:DelSame (PtLst Fuzz) 
                (if PtLst 
                  (cons (car PtLst) 
                        (K:DelSame 
                          (vl-remove-if '(lambda (XX) (equal XX (car PtLst) Fuzz)) 
                                        (cdr PtLst)
                          )
                          Fuzz
                        )
                  )
                )
              )
              ;获取最近点并且绘制线,TgtPT为WCS
              (defun K:GetEndPTLst (ObjLst TgtPT TgtCol / XX ColEn EndPT PtLst)
                  (setq PtLst Nil)
                  (if ColEn (vla-Delete (vlax-ename->vla-object ColEn)));删除临时实体
                  (foreach XX ObjLst
                      (if 
                        (not 
                          (vl-catch-all-error-p 
                            (setq EndPT (vl-catch-all-apply 'vlax-curve-getClosestPointTo (list XX TgtPT)))
                          )
                        )
                        (setq PtLst (cons EndPT PtLst))
                      )
                  );收集最近点
                  (redraw)
                  (if (setq PtLst (K:DelSame PtLst 0.001))
                      (foreach XX PtLst
                        (grdraw (trans TgtPT 0 1) (trans XX 0 1) TgtCol);UCS
                      )
                  )
                  PtLst
              )
              ;获取模式字符串
              (defun K:GetMdeSTR ()
                    (cond 
                      ((eq Global:RvMde "1") "修改")
                      ((eq Global:RvMde "2") "批注")
                      ((eq Global:RvMde "3") "检查")
                    )
              )
              ;获取目标字符串
              (defun K:GetTgtSTR (Time HNam / TmpSTR)
                  (setq TmpSTR (K:GetMdeSTR));模式STR
                  (cond 
                      ((eq Global:RvPre "1") (strcat TmpSTR "时间+" TmpSTR "内容"))
                      ((eq Global:RvPre "2") (strcat TmpSTR "时间+" TmpSTR "人员"))
                      ((eq Global:RvPre "3") (strcat TmpSTR "人员+" TmpSTR "内容"))
                      ((eq Global:RvPre "4") (strcat TmpSTR "人员+" TmpSTR "时间+" TmpSTR "内容"))
                      ((eq Global:RvPre "5") (strcat TmpSTR "内容"))
                      ((eq Global:RvPre "6") (strcat Time))
                      ((eq Global:RvPre "7") (strcat HNam))
                      ((eq Global:RvPre "8") (strcat Global:RvUSE))
                  )
              )
          )
          (setq TipHNam (getenv "USERNAME")
                TipTime (menucmd "M=$(edtime,$(getvar,date),YYYY/MO/DD)")
                TipMSTR (K:GetMdeSTR);模式STR
          )
          (if
              (setq EntLst 
                    (vl-remove-if-not 
                        '(lambda (XX) 
                          (member 
                            (Cdr (Assoc 0 (Entget XX)))
                            (list "LINE" "ARC" "CIRCLE" "ELLIPSE" "POLYLINE" "LWPOLYLINE" "SPLINE")
                          )
                        )
                        EntLst
                    )
              );只保留符合条件的对象
              (progn
                  (if (null TmpSCV)(setq TmpSCV 2));放大倍数默认2
                  (setq ObjLst (mapcar 'vlax-ename->vla-object EntLst));图元表转实体表
                  (setq StaPT Nil PtLst Nil)(redraw)
                  (if (eq "8" Global:RvPre)
                      (princ (strcat "\n——★★★ 当前自定义字符串<" Global:RvUSE "> ★★★——\n"))(princ)
                  )
                  (setq RvTipEn  (entmakeX
                                    (list 
                                        (cons 0 "TEXT")
                                        (cons 62 TgtCol);颜色
                                        (cons 10 (list 0.0 0.0 0.0))
                                        (cons 1 (K:GetTgtSTR TipTime TipHNam));文字内容
                                        (cons 40 (* TgtDIM 2.0));字高
                                        (cons 50 (- (* 2 pi) (getvar "viewtwist")));文字旋转始终水平视图
                                    )
                                )     
                  );单行提示文字
                  (while ;Grread
                    (progn
                      (princ 
                        (strcat 
                            "\n→请指定标注点或空格: ["
                            (if (not (member Global:RvPre (list "6" "7" "8")))
                                (strcat "模:" (K:GetMdeSTR) "(E)")
                                ""
                            )
                            "/字:"
                            (cond
                                ((eq Global:RvPre "1") "时间内容(F)/(B)" )
                                ((eq Global:RvPre "2") "时间内容(F)/(B)" )
                                ((eq Global:RvPre "3") "人员内容(F)/(B)" )
                                ((eq Global:RvPre "4") "人员时间内容(F)/(B)")
                                ((eq Global:RvPre "5") "仅内容(F)/(B)" );到这里
                                ((eq Global:RvPre "6") "仅时间(F)/(B)" )
                                ((eq Global:RvPre "7") "仅人员(F)/(B)" )
                                ((eq Global:RvPre "8") "自定义(F)/(B)" )
                            )
                            "/比例(S输)_"(rtos TgtDIM 2 1)"/(W增)/(D减)"
                            "/倍数(R)_" (rtos TmpSCV 2 1)
                            "]"
                        )
                      )
                      (while (and (setq Code (grread T (+ 1 4 8) 0)) (eq (car Code) 5)) 
                          (redraw)
                          (setq StaPT (trans (cadr Code) 1 0));WCS
                          (setq PtLst (K:GetEndPTLst ObjLst StaPT TgtCol));WCS
                          (entmod 
                              (append
                                  (list 
                                      (assoc -1 (entget RvTipEn))
                                      (cons 10 StaPT)   
                                  )
                                  (if (> (cadr (mapcar '- (trans StaPT 0 1)(trans (car PtLst) 0 1))) 0);Y大,上侧
                                      (list (cons 73 0));左下
                                      (list (cons 73 3)(cons 11 StaPT));左上
                                  );对齐基点
                              )
                          );更新提示文字坐标
                      )
                      (cond
                        ((and (eq (car Code) 3) (eq (type StaPT) 'LIST));点选
                            Nil ;退出循环
                        )
                        ((equal Code '(2 32));空格
                            (redraw)
                            (setq StaPT (trans (cadr (grread '(2 32))) 1 0)) ;WCS
                            (setq PtLst (K:GetEndPTLst ObjLst StaPT TgtCol));WCS
                            Nil ;退出循环
                        )
                        (
                          (and ;字母E
                              (not (member Global:RvPre (list "6" "7" "8")))
                              (or
                                (eq (cadr Code) 69)
                                (eq (cadr Code) (+ 69 32))
                              )
                          )
                          (setq Global:RvMde 
                              (cond 
                                ((eq Global:RvMde "1") "2")
                                ((eq Global:RvMde "2") "3")
                                ((eq Global:RvMde "3") "1")
                              )
                          )
                          (setq TipMSTR (K:GetMdeSTR));模式STR
                          (entmod 
                              (list (assoc -1 (entget RvTipEn)) 
                                    (cons 1 (K:GetTgtSTR TipTime TipHNam));文字内容
                              )
                          );更新文字
                          T ;继续循环
                        )
                        ((or ;字母F
                            (eq (cadr Code) 70)
                            (eq (cadr Code) (+ 70 32))
                          )
                          (setq Global:RvPre 
                              (cond 
                                ((eq Global:RvPre "1") "2")
                                ((eq Global:RvPre "2") "3")
                                ((eq Global:RvPre "3") "4")
                                ((eq Global:RvPre "4") "5")
                                ((eq Global:RvPre "5") "6")
                                ((eq Global:RvPre "6") "7")
                                ((eq Global:RvPre "7") "8")
                                ((eq Global:RvPre "8") "1")
                              )
                          )
                          (if (eq "8" Global:RvPre)
                              (progn
                                  (setq UseFlag T)
                                  (while 
                                      (and
                                          UseFlag 
                                          (setq TmpSTR (getstring Nil (strcat "\n→请输入自定义非空字符串(空格确认):<" Global:RvUSE ">")))
                                      )
                                      (if (eq "" TmpSTR);空
                                        (progn 
                                            (princ (strcat "\n——★★★ 未修改自定义字符串<" Global:RvUSE "> ★★★——\n"))
                                            (setq UseFlag Nil) ;退出循环
                                        )
                                        (progn 
                                            (setq Global:RvUSE TmpSTR)
                                            (princ (strcat "\n——★★★ 已修改自定义字符串为<" Global:RvUSE "> ★★★——\n"))
                                            ;(K:SetGetData T "K\\RRSysNam" *MkVarLst*);用全局更新系统和黑板
                                            (setq UseFlag Nil) ;退出循环
                                        )
                                      )
                                      (princ)
                                  )
                              )
                          )
                          (setq TipMSTR (K:GetMdeSTR));模式STR
                          (entmod 
                              (list (assoc -1 (entget RvTipEn)) 
                                    (cons 1 (K:GetTgtSTR TipTime TipHNam));文字内容
                              )
                          );更新文字
                          T ;继续循环
                        )
                        ((or ;字母B
                            (eq (cadr Code) 66)
                            (eq (cadr Code) (+ 66 32))
                          )
                          (setq Global:RvPre 
                              (cond 
                                ((eq Global:RvPre "1") "8")
                                ((eq Global:RvPre "2") "1")
                                ((eq Global:RvPre "3") "2")
                                ((eq Global:RvPre "4") "3")
                                ((eq Global:RvPre "5") "4")
                                ((eq Global:RvPre "6") "5")
                                ((eq Global:RvPre "7") "6")
                                ((eq Global:RvPre "8") "7")
                              )
                          )
                          (if (eq "8" Global:RvPre)
                              (progn
                                  (setq UseFlag T)
                                  (while 
                                      (and
                                          UseFlag 
                                          (setq TmpSTR (getstring Nil (strcat "\n→请输入自定义非空字符串(空格确认):<" Global:RvUSE ">")))
                                      )
                                      (if (eq "" TmpSTR);空
                                        (progn 
                                            (princ (strcat "\n——★★★ 未修改自定义字符串<" Global:RvUSE "> ★★★——\n"))
                                            (setq UseFlag Nil) ;退出循环
                                        )
                                        (progn 
                                            (setq Global:RvUSE TmpSTR)
                                            (princ (strcat "\n——★★★ 已修改自定义字符串为<" Global:RvUSE "> ★★★——\n"))
                                            ;(K:SetGetData T "K\\RRSysNam" *MkVarLst*);用全局更新系统和黑板
                                            (setq UseFlag Nil) ;退出循环
                                        )
                                      )
                                      (princ)
                                  )
                              )
                          )
                          (setq TipMSTR (K:GetMdeSTR));模式STR
                          (entmod 
                              (list (assoc -1 (entget RvTipEn)) 
                                    (cons 1 (K:GetTgtSTR TipTime TipHNam));文字内容
                              )
                          );更新文字
                          T ;继续循环
                        )
                        ((or ;字母S
                            (eq (cadr Code) 83)
                            (eq (cadr Code) (+ 83 32))
                          )
                          (if
                            (progn
                                (initget (+ 2 4)) ;非零非负关键词
                                (setq TgtDIM 
                                    (cond
                                        ((getreal (strcat "\n→请输入新的标字比例<" (rtos TgtDIM 2 1) ">")))
                                        (TgtDIM);空格回车使用上次的值
                                    )
                                )
                            )
                            (progn
                                (if (and (eq (getvar "TILEMODE") 0)(eq (getvar "CVPORT") 1));布局空间
                                    (setq Global:RvDIM (rtos TgtDIM 2 5));更新云线比例
                                    (if (type (eval (read "TsetPScale")));存在天正命令
                                        (TsetPScale TgtDIM);设置天正比例
                                        (setq Global:RvDIM (rtos TgtDIM 2 5));更新云线比例
                                    )
                                )
                                (entmod (list (assoc -1 (entget RvTipEn))(cons 40 (* TgtDIM 5.0))));更新大小
                            )
                          )
                          T ;继续循环
                        )
                        ((or ;字母W
                            (eq (cadr Code) 87)
                            (eq (cadr Code) (+ 87 32))
                          )
                          (setq TgtDIM (+ TgtDIM TmpSCV))
                          (progn
                              (if (type (eval (read "TsetPScale")));存在天正命令
                                  (TsetPScale TgtDIM)
                                  (setvar "DIMSCALE" TgtDIM);设置CAD标注比例
                              );更新比例
                              (entmod (list (assoc -1 (entget RvTipEn))(cons 40 (* TgtDIM 5.0))));更新大小
                          )
                          T ;继续循环
                        )
                        ((or ;字母D
                            (eq (cadr Code) 68)
                            (eq (cadr Code) (+ 68 32))
                          )
                            (if (> TgtDIM TmpSCV)
                                (progn
                                    (setq TgtDIM (- TgtDIM TmpSCV))
                                    (progn
                                        (if (type (eval (read "TsetPScale")));存在天正命令
                                            (TsetPScale TgtDIM)
                                            (setvar "DIMSCALE" TgtDIM);设置CAD标注比例
                                        );更新比例
                                        (entmod (list (assoc -1 (entget RvTipEn))(cons 40 (* TgtDIM 5.0))));更新大小
                                    )
                                )
                                (princ "\n——★★★ 当前比例小于倍数，无法再减少！ ★★★——\n")
                            )
                            T ;继续循环
                        )
                        ((or ;字母R
                            (eq (cadr Code) 82)
                            (eq (cadr Code) (+ 82 32))
                          )
                          (progn
                              (initget (+ 2 4)) ;非零非负关键词
                              (setq TmpSCV 
                                  (cond
                                      ((getreal (strcat "\n→请输入新的增减倍数<" (rtos TmpSCV 2 1) ">")))
                                      (TmpSCV);空格回车使用上次的值
                                  )
                              )
                          )
                          T ;继续循环
                        )
                        (T 
                          (princ Code)
                          (princ "\n——★★★ 请指定点、输入关键词或 ESC退出！ ★★★——\n")
                          T ;继续循环
                        )
                      )
                    )
                  )
                  
                  (princ "\n");清空命令行
                  (if RvTipEn (vla-delete (vlax-ename->vla-object RvTipEn)));删除临时文字
                  (if (and StaPT PtLst)
                      (progn
                          (setq TipMSTR (K:GetMdeSTR));模式STR
                          (foreach XX PtLst
                              (regapp "RvData");为扩展数据注册程序名
                              (entmake (list 
                                          (cons 0 "LINE") 
                                          (cons 62 TgtCol);颜色
                                          (if (eq Global:RvSLa "2") 
                                              (cons 8 (Last LayLst))
                                              (cons 8 (if (eq "1" Global:RvLay) (car LayLst) (cadr LayLst)))
                                          )
                                          (cons 10 StaPT)
                                          (cons 11 XX)
                                          (list 
                                            -3
                                            (list 
                                              "RvData"
                                              (cons 1000 TipHNam);人员
                                              (cons 1000 TipTime);时间
                                            )
                                          )
                                        )
                              );直线
                          )
                          (regapp "RvData");为扩展数据注册程序名
                          (setq MTEN
                              (entmakeX
                                  (list (cons 0 "MTEXT") 
                                        (cons 100 "AcDbEntity")
                                        (cons 100 "AcDbMText")
                                        (cons 10 StaPT)
                                        (cons 62 TgtCol);颜色
                                        (cons 40 (* TgtDIM 2.0));字高
                                        (cons 41 (* TgtDIM 50.0));总页宽
                                        (if (eq Global:RvSLa "2")
                                            (cons 8 (Last LayLst))
                                            (cons 8 (if (eq "1" Global:RvLay) (car LayLst) (cadr LayLst)))
                                        )
                                        (cons 71
                                            (if (> (cadr (mapcar '- (trans StaPT 0 1)(trans (car PtLst) 0 1))) 0);Y大,上侧
                                                7 ;左下
                                                1 ;左上
                                            )
                                        );对齐基点
                                        (cons 1 
                                            (cond
                                                ((eq Global:RvPre "1")(strcat TipMSTR "时间：" TipTime "\n" TipMSTR "内容："))
                                                ((eq Global:RvPre "2")(strcat TipMSTR "时间：" TipTime "\n" TipMSTR "人员："))
                                                ((eq Global:RvPre "3")(strcat TipMSTR "人员：" TipHNam "\n" TipMSTR "内容："))
                                                ((eq Global:RvPre "4")(strcat TipMSTR "人员：" TipHNam "\n" TipMSTR "时间：" TipTime "\n" TipMSTR "内容："))
                                                ((eq Global:RvPre "5")(strcat TipMSTR "内容："))
                                                ((eq Global:RvPre "6")(strcat TipTime "："))
                                                ((eq Global:RvPre "7")(strcat TipHNam "："))
                                                ((eq Global:RvPre "8") Global:RvUSE)
                                            )
                                        );文字内容
                                        (cons 50 (- 
                                                  (- (* 2 pi) (getvar "viewtwist"))
                                                  (angle '(0. 0. 0.) (trans (getvar 'UCSXDIR) 0 (trans '(0. 0. 1.) 1 0 t) t))
                                                )
                                        );文字旋转始终水平视图
                                        ;|文字加边框
                                          (cons 90 16);加边框
                                          (cons 63 256);背景填充的颜色
                                          (cons 45 1.5);边框与字间距
                                          (cons 441 0);背景色透明度
                                        |;
                                        (list 
                                            -3
                                            (list 
                                              "RvData"
                                              (cons 1000 TipHNam);人员
                                              (cons 1000 TipTime);时间
                                            )
                                        )
                                  )
                              );多行文字
                          )
                          (if MTEN 
                              (progn
                                  (command "_.MTEDIT" MTEN)
                                  (while (> (getvar "CMDACTIVE") 0) (command PAUSE));等待前面的命令完成
                              )
                          );编辑多行文字
                      )
                  )
                  (redraw);刷新视图
              )
              (princ "\n——★★★ 请选择直线、圆弧、圆、椭圆、多段线、样条曲线！ ★★★——\n")
          )
      )
      ;根据矩形对角点生成标记叉并判断是否关闭视口
      (defun Rv:DrawMkBox (StaPT DiaPT Col / X1 x2 Y1 y2 PtLst TgtEn ObjLst XX) 
          ;根据两点框选收集所有显示的视口成对象表(含裁剪视口)
          (defun K:GetVP4TwoPT (StaPT DiaPT / SSVP i en ent obj ObjLst) 
              (setq ObjLst nil)
              (setq SSVP 
                  (ssget "C" StaPT DiaPT
                    (list 
                      (cons -4 "<OR")
                        (cons -4 "<AND")
                          (cons -4 "<OR")
                            (cons 0 "LWPOLYLINE") ;多段线
                            (cons 0 "ELLIPSE") ;椭圆
                            (cons 0 "CIRCLE") ;圆
                          (cons -4 "OR>")
                          ;(cons 102 "{ACAD_REACTORS");视口裁剪
                        (cons -4 "AND>")
                        (cons 0 "VIEWPORT")
                      (cons -4 "OR>")
                    )
                  )
              );选择视口(含裁剪)
              (if SSVP 
                (progn
                    (repeat (setq i (sslength SSVP)) 
                      (setq en (ssname SSVP (setq i (1- i)))
                            ent (entget en)
                      )
                      (if 
                          (and  
                            (setq ent (member '(102 . "{ACAD_REACTORS") ent))
                            (setq ent (member '(102 . "}") (reverse ent)))
                          )
                          (setq en (cdr (assoc 330 ent)))
                      );如果视口裁剪就更新图元名
                      (if   
                          (and
                              (eq "VIEWPORT" (Cdr (Assoc 0 (Entget en))));是视口
                              (eq :vlax-true (vla-get-viewporton (setq obj (vlax-ename->vla-object en))));视口显示
                              (not (member obj ObjLst));选择集去重
                          )
                          (setq ObjLst (cons obj ObjLst))
                      )
                    )
                )
              )
              ObjLst
          )
          (progn ;生成框叉
              (setq X1 (max (car StaPT) (car DiaPT))
                    x2 (min (car StaPT) (car DiaPT))
                    Y1 (max (cadr StaPT) (cadr DiaPT))
                    y2 (min (cadr StaPT) (cadr DiaPT))
              )
              (setq PtLst 
                (list
                  (list X1 Y1);左上
                  (list X1 y2);左下
                  (list x2 Y1);右上
                  (list x2 y2);右下
                  (list X1 Y1);左上
                )
              )
              (regapp "MkBox");为扩展数据注册程序名
              (setq TgtEn
                (entmakex 
                  (append 
                    (list '(0 . "LWPOLYLINE") 
                          '(100 . "AcDbEntity")
                          '(100 . "AcDbPolyline")
                          (cons 6 "Continuous");实线
                          (cons 62 Col);颜色
                          (cons 90 (length PtLst));顶点数
                          (cons 70 1);闭合
                          ;(cons 43 0.5);线宽0.5
                    )
                    (mapcar '(lambda (pt) (cons 10 (trans pt 1 0))) PtLst)
                    (list 
                      (list -3 
                          (list "MkBox"
                              (cons 1000 (getenv "USERNAME"));人员
                              (cons 1000 (menucmd "M=$(edtime,$(getvar,date),YYYY/MO/DD)"));时间
                          )
                      )
                    )
                  )
                );绘制外围矩形
              )
              (Rv:PutRvData TgtEn)
          )
          (if (not Global:SVMde) (setq Global:SVMde "Y"))
          (if 
            (and 
              (eq (getvar "TILEMODE") 0)
              (eq (getvar "CVPORT") 1)
              (setq ObjLst (K:GetVP4TwoPT StaPT DiaPT))
              (progn
                  (initget "Y N");非零非负值
                  (setq Global:SVMde (cond 
                                  ((getkword (strcat "关闭显示下方视口避免卡顿?:[Y/N]: <" Global:SVMde ">")))
                                  (Global:SVMde)
                                )
                  )
              );获取转换模式
              (eq Global:SVMde "Y")
            );布局空间且有视口
            (foreach XX ObjLst (vla-put-ViewportOn XX :vlax-false));关闭视口
          )
          TgtEn
      )
      ;根据SS获取RvData并CSV文件,之后打开
      (defun Rv:Data2CSV (TgtSS / i RvSTR RvDat PosFlg RvLst FlieNam OpenFile StaNum XX)
          (setq RvDat Nil RvLst Nil);清空变量避免串门
          (repeat (setq i (sslength TgtSS)) 
              (setq en    (ssname TgtSS (setq i (1- i)))
                    RvSTR (Cdr (Assoc 1 (Entget en))) ;文字内容
                    RvDat (mapcar 'cdr (cdadr (assoc -3 (entget en '("RvData"))))) ;扩展数据:人员+日期
              )
              (setq RvLst (cons (append (list (car RvDat) (cadr RvDat)) (list (K:SubstAllSTR "，" "," (K:MText2Text RvSTR)))) RvLst))
          );收集扩展数据
          (if RvLst
              (progn
                  (setq StaNum 1);起始序号为1
                  (setq FlieNam (vl-filename-mktemp "REVC" nil ".CSV"));临时创建文件
                  (setq OpenFile (open FlieNam "W"))
                  (Write-Line "序号,圈注人员,圈注日期,圈注内容" OpenFile)
                  (mapcar
                    '(lambda (XX)
                        (Write-Line 
                            (strcat 
                              (itoa StaNum) ","
                              (K:Lst->STR XX ",")
                            )
                            OpenFile
                        );写一行
                        (setq StaNum (1+ StaNum))
                    )
                    (vl-sort RvLst '(lambda (a b) (> (car a) (car b))));按人员排序
                  )
                  (close OpenFile)
                  (setq XX (vlax-get-or-create-object "Wscript.Shell"))
                  (vlax-invoke XX'RUN FlieNam );(打开任意已经建立关联程序的文件)
                  (vlax-release-object winshell)
              )
          )
      )
      ;旧云线自动图层
      (defun Rv:OldAutoLay (TgtSS / CurTim i en OriDATA EnLst XX)
          (setq CurTim (menucmd "M=$(edtime,$(getvar,date),YYYY/MO/DD)"))
          (if TgtSS
              (progn
                (repeat (setq i (sslength TgtSS)) 
                    (setq en (ssname TgtSS (setq i (1- i))))
                    (setq OriDATA (assoc -3 (entget en '("RvData"))))
                    (if (/= (Last (mapcar 'cdr (cdadr OriDATA))) CurTim);不是今天
                        (setq EnLst (cons (cons en (mapcar 'cdr (cdadr OriDATA))) EnLst))
                    )
                );收集数据
                (if EnLst
                    (progn
                        (foreach XX EnLst
                            (setq LayNam (strcat "K-云线-" (substr (apply 'strcat (K:STR->Lst (last XX) "/")) 3 6) "_云线不打印"))
                            (K:GetNewLay LayNam 252 :vlax-false);新建或更新深灰色云线图层不可打印图层
                            (vla-put-layer (vlax-ename->vla-object (car XX)) LayNam)
                        )
                        (princ (strcat "\n——★★★ 共自动规整了<" (rtos (length EnLst) 2 0) ">个非当前日期的云线 ★★★——\n"))
                    )
                    (princ (strcat "\n——★★★ 未发现任何不是今天的云线 ★★★——\n"))
                )
                (princ)
              )
          )
      )
      ;修改云线日期，并移动云线到图层
      (defun Rv:MvtoLay (TgtSS LayNam / CurTim i en OriDATA)
          (setq CurTim (menucmd "M=$(edtime,$(getvar,date),YYYY/MO/DD)"))
          (if TgtSS
                (repeat (setq i (sslength TgtSS)) 
                    (setq en (ssname TgtSS (setq i (1- i))))
                    (setq OriDATA (assoc -3 (entget en '("RvData"))))
                    (if (/= (Last (mapcar 'cdr (cdadr OriDATA))) CurTim);不是今天
                            (entmod 
                              (append 
                                (entget en)
                                (list 
                                  (list 
                                    -3
                                    (cons 
                                      "RvData"
                                      (subst 
                                        (cons 1000 CurTim)
                                        (nth 1 (cdadr OriDATA));替换第二项的日期
                                        (cdadr OriDATA)
                                      )
                                    )
                                  )
                                )
                              )
                            )
                    )
                    (vla-put-layer (vlax-ename->vla-object en) LayNam)
                );更新日期
          )
      )

    )
    (progn ;基础函数
      (progn ;字符串拆分与合并
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
      ;获取或更新变量(系统+全局+黑板),不存在时更新为默认值(系统变量记录的全局变量值使用@@分隔)
      (defun K:SetGetData (RecDATA SysNam VarLst  / XX SysLst a b) 
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
      ;新建图层：图层名称、图层颜色、是否打印(:vlax-false不打印，:vlax-true打印)
      (defun K:GetNewLay (LayNam Col Plt / TgtEn TgtObj) 
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
      ;选择集转实体表@Lee Mac
      (defun K:SS->EntLst (TgtSS / i en EntLst) 
        (if TgtSS 
          (repeat (setq i (sslength TgtSS)) 
            (setq en (ssname TgtSS (setq i (1- i))))
            (setq EntLst (cons en EntLst))
          )
        )
      )
      ;返回实体或对象最小边界框的WCS坐标(左下角和右上角)@Gu_xl
      (defun K:GetWCSBox (obj / p1 p2 p3 p4 WCSBox) 
          (if (eq 'ENAME (type obj))(setq obj (vlax-ename->vla-object obj)))
          (vla-GetBoundingBox obj 'p1 'p3)
          (setq p1 (vlax-safearray->list p1)
                p3 (vlax-safearray->list p3)
                p2 (list (car p1) (cadr p3) (caddr p1))
                p4 (list (car p3) (cadr p1) (caddr p1))
          )
          (if (eq "AcDbSpline" (Vla-Get-ObjectName obj));样条曲线取投影
              (progn 
                (setq WCSBox (mapcar 
                                '(lambda (a b) (vlax-curve-getClosestPointToProjection obj a b t))
                                (list p1 p2 p3 p4)
                                '((1.0 0 0) (0 -1.0 0) (-1.0 0 0) (0 1.0 0))
                            )
                )
                (list 
                    (apply 'mapcar (cons 'min WCSBox));表中最小
                    (apply 'mapcar (cons 'max WCSBox));表中最大
                )
              )
              (list p1 p3)
          )
      )
      ;返回实体或对象最小边界框的UCS坐标(左下角和右上角)@Kucha
      (defun K:GetUCSBox (obj / K:CvtMatrix UCSBox)
        (if (eq 'ENAME (type obj))(setq obj (vlax-ename->vla-object obj)))
        ;矩阵转换/坐标系转换
        (defun K:CvtMatrix (from to) 
          (append 
            (mapcar 
              (function 
                (lambda (v o) 
                  (append (trans v from to t) (list o))
                )
              )
              '((1.0 0.0 0.0)
                (0.0 1.0 0.0)
                (0.0 0.0 1.0)
              )
              (trans '(0.0 0.0 0.0) to from)
            )
            '((0.0 0.0 0.0 1.0))
          )
        )
        (vla-transformby obj (vlax-tmatrix (K:CvtMatrix 1 0)));对象转换到WCS
        (setq UCSBox (K:GetWCSBox obj));获取转换后的最小矩形框(WCS)
        (vla-transformby obj (vlax-tmatrix (K:CvtMatrix 0 1)));对象转换回UCS
        UCSBox
      )
      ;两点获取四边形四点UCS
      (defun K:GetRecPtLst (StaPT DiaPT / X1 x2 Y1 y2) 
        (setq X1 (max (car StaPT) (car DiaPT))
              x2 (min (car StaPT) (car DiaPT))
              Y1 (max (cadr StaPT) (cadr DiaPT))
              y2 (min (cadr StaPT) (cadr DiaPT))
        )
        (list
            (list x2 y2);左下
            (list x2 Y1);左上
            (list X1 Y1);右上
            (list X1 y2);右下   
        )
      )
    )
    (progn ;生成CSV的基础函数
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
        ;使用分隔符串联字符串@LeeMac
        (defun K:Lst->STR (Lst Del / STR )
          (setq STR (car Lst))
          (foreach itm (cdr Lst) (setq STR (strcat STR Del itm)))
          STR
        )
        ;用NewSTR替换字符串中所有的OldSTR@vitalgg
        (defun K:SubstAllSTR (NewSTR OldSTR TgtSTR / inc len) 
          (if (> (strlen OldSTR) 0) 
            (progn 
              (setq len (strlen NewSTR)
                    inc 0
              )
              (while (setq inc (vl-string-search OldSTR TgtSTR inc)) 
                  (setq TgtSTR (vl-string-subst NewSTR OldSTR TgtSTR inc)
                        inc    (+ inc len)
                  )
              )
            )
          )
          TgtSTR
        )
    )

    (while (eq 8 (logand 8 (getvar 'undoctl))) 
      (vla-endundomark CurDoc)
    ) ;关闭以前的编组
    (vla-startundomark CurDoc) ;记录编组
      (progn ;基础变量赋值
        (setq *MkVarLst*
            (list 
              (list "Global:RvDyn" "1");1静态,-1动态
              (list "Global:RvLay" "1");1默认层,2当前层
              (list "Global:RvTXT" "2");1标注文字,2不标文字
              (list "Global:RvSLa" "2");1字相同层,2字不同层
              (list "Global:RvMde" "1");1修改,2批注,3检查
              (list "Global:RvPre" "5");1时间内容,2时间人员,3人员内容,4人员时间内容,5仅内容,6仅时间,7仅人员,8自定义
              (list "Global:RvUSE" "变更01:");8自定义内容
              (list "Global:RvDIM" (rtos (getvar "DIMSCALE") 2 2));布局的标注比例
            )
        );参数列表，自行扩写
        (K:SetGetData Nil "K\\RRSysNam" *MkVarLst*);用黑板更新系统和全局(缺省取默认)
        (if (not Global:ArLen) 
            (if (getenv "K\\REVCLOUD-ArLen")
                (setq Global:ArLen (atof (getenv "K\\REVCLOUD-ArLen")))
                (setenv "K\\REVCLOUD-ArLen" (rtos (setq Global:ArLen 5) 2 1))
            )
        );最大弧长默认为5

        (if (and 
                (eq Global:RvDyn "1");1静态
                (>= Global:ArLen 50)
                (eq (getvar "TILEMODE") 0)
                (eq (getvar "CVPORT") 1)
            );布局空间
            (setenv "K\\REVCLOUD-ArLen" (rtos (setq Global:ArLen 50) 2 1))
        );布局空间静态弧长默认最大不超过50,避免模型动态转布局静态,弧长太大可能导致无法生成云线
        (setq TmpCol "1" TXTCol "44");默认云线层红色,文字淡黄(目前只支持索引色)

        (setq TmpDIM
            (if (and (eq (getvar "TILEMODE") 0)(eq (getvar "CVPORT") 1));布局空间
                (atof Global:RvDIM)
                (if (type (eval (read "TGetPScale")));存在天正命令
                    (/ (TGetPScale) 1.0);获取天正比例(实数)
                    (atof Global:RvDIM);获取云线比例
                )
            )
        );文字比例,始终等于标注比例或者天正比例
        (setq LayLst (list 
                      (strcat "K-云线-存放层")
                      (getvar "CLAYER")
                      (strcat "K-云线-线不印")
                      (strcat "K-云线-字不印")
                    )
        )
        (if (not (tblobjname "layer" (car LayLst))) ;没有的时候才新建并更新
            (K:GetNewLay (car LayLst) (atoi TmpCol) :vlax-true)
        );如果云线图层不存在，则新建可打印图层
        (K:GetNewLay (caddr LayLst) 252 :vlax-false);新建或更新深灰色云线图层不可打印图层
        (K:GetNewLay (Last LayLst) (atoi TXTCol) :vlax-false);新建或更新黄色云线文字图层不可打印图层
        
        (setq LayFrz nil);假设默认图层未冻结
        (if 
            (and
              (eq "1" Global:RvLay)
              (eq 1 (logand 1 (cdr (assoc 70 (tblsearch "LAYER" (car LayLst))))))
            );默认层已冻结
            (progn
                (setq Global:RvLay "2")
                (setq LayFrz T)
                (princ (strcat "\n——★★★ 默认层<" (car LayLst) ">已冻结, 云线将放在当前图层! ★★★——\n"))
            )
        );如果默认层冻结，则切换到当前层，并且后续恢复
        (if 
            (and
                (eq "1" Global:RvLay)
                (eq 4 (logand 4 (cdr (assoc 70 (tblsearch "LAYER" (car LayLst))))))
            );默认层锁定
            (progn
                (setq Global:RvLay "2")
                (alert (strcat "\n默认层<" (car LayLst) ">已锁定\n云线将放在当前图层!\n"))
            )
        );如果默认图层锁定，则切换到当前层，并且后续不恢复
      )
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
                (list "CLayer" (if (eq "1" Global:RvLay) (car LayLst) (cadr LayLst)));切换图层
                ;(list "CECOLOR" (Rv:GetHMCol (rtos (getvar "CDATE") 2 0)));伪随机色
                (list "RevcloudCreateMode" 1);使用矩形的方式绘制云线
                (list "RevcloudArcStyle" "Calligraphy");云线为手绘风格
                (list "AutoSnap" 39) ;关闭极轴追踪和对象捕捉追踪
                (list "CMDECHO" 0) ;关闭回显
              )
            )
        );记录参数
      )
      (if (null (last (ssgetfirst))) ;没有预选对象
          (if (eq 4 (logand 4 (cdr (assoc 70 (tblsearch "LAYER" (getvar "CLAYER"))))))
              (alert (strcat "※当前图层已锁定, 无法运行程序！"))
              (progn
                (if (/= TmpCol (setq CurCol (rtos (Rv:Cecolor4ACI) 2 0)))
                    (setq TmpCol CurCol)
                );避免使用RGB等颜色出错
                (setq HasGetRv Nil);默认没有生成云线
                (while 
                  (progn
                    (setq RvLayObj (vlax-ename->vla-object (tblobjname "layer" (if (eq "1" Global:RvLay) (car LayLst) (cadr LayLst)))));图层对象
                    (princ 
                      (strcat 
                        (if (and HasGetRv (eq Global:RvTXT "2"))
                            "\n→请继续指定矩形角点或空格退出: ["
                            "\n→请指定矩形角点或空格选对象: ["
                        )
                        (if (eq Global:RvDyn "1") 
                          (strcat "/静(D)_" (rtos Global:ArLen 2 1))
                          "/动(D)"
                        )
                        (if (eq Global:RvTXT "1") 
                            (strcat "/有字(T)_" (rtos TmpDIM 2 1) (if (eq Global:RvSLa "1") "/字同层(G)" "/字单层(G)"))
                            "/无字(T)"
                        )
                        (if (eq Global:RvLay "1") "/默认层(L)" "/当前层(L)")
                        (if (eq :vlax-true (vla-get-Plottable RvLayObj))
                            "/层可印(P)"
                            "/层不印(P)"
                        )
                        "/重置(R)/选标(S)/导出(E)/框叉(B)/随机色(C)"
                        "]"
                      )
                    )
                    (while (and (setq Code (grread T (+ 1 4 8))) (eq (car Code) 5)))
                    (cond
                      ((and ;点选
                        (eq (car Code) 3)
                        (eq (type (setq TgtPT (cadr Code))) 'LIST)
                        )
                        (if (setq RvEn (Rv:DrawDynRvEn TgtPT (atoi TmpCol)));动态绘制矩形或封闭多边形
                            (if (eq "1" Global:RvDyn);1静态
                                (if
                                    (and
                                      (princ (strcat "\n——★★★ 推荐使用最大弧长为: " (rtos (Rv:RecSugArLen RvEn) 2 0)" ★★★——\n"))
                                      (progn
                                          (initget (+ 2 4) "D")
                                          (setq TmpArLen ;设置弧长
                                              (cond 
                                                ((getreal (strcat  "\n→请输入最大弧长[临时动态(D)]: <"(rtos Global:ArLen 2 1)">")))
                                                (Global:ArLen)
                                              )
                                          )
                                      )
                                    )
                                    (if (eq TmpArLen "D");字母D临时动态
                                        (progn
                                            (setq NewLst (Rv:DynCloudLine RvEn Nil)
                                                  NewEn (car NewLst)
                                                  Global:ArLen (cadr NewLst)
                                            )
                                            (if NewEn
                                                (progn
                                                    (Rv:PutRvData NewEn);为对象添加扩展数据
                                                    (if (eq Global:RvTXT "1") ;1标注文字,2不标文字
                                                        (Rv:CreatRvTXT (atoi TXTCol) TmpDIM (list NewEn))
                                                    )
                                                    (setenv "K\\REVCLOUD-ArLen" (rtos Global:ArLen 2 1));储存最大弧长为环境变量
                                                )
                                            )
                                        )
                                        (progn
                                          (setq Global:ArLen TmpArLen)
                                          (while (> (getvar "CMDACTIVE") 0) (command PAUSE));等待前面的命令完成
                                          (setq e0 (EntLast))
                                          (command "_.REVCLOUD" "A" Global:ArLen Global:ArLen "O" RvEn "N");创建云线
                                          (setq NewEn (EntNext e0))
                                          (if NewEn
                                              (progn
                                                  (Rv:PutRvData NewEn);为对象添加扩展数据
                                                  (if (eq Global:RvTXT "1") ;1标注文字,2不标文字
                                                      (Rv:CreatRvTXT (atoi TXTCol) TmpDIM (list NewEn))
                                                  )
                                              )
                                          )
                                          (setenv "K\\REVCLOUD-ArLen" (rtos Global:ArLen 2 1));储存最大弧长为环境变量
                                        )
                                    )
                                )
                                (progn
                                    (setq NewLst (Rv:DynCloudLine RvEn Nil)
                                          NewEn (car NewLst)
                                          Global:ArLen (cadr NewLst)
                                    )
                                    (if NewEn
                                        (progn
                                            (Rv:PutRvData NewEn);为对象添加扩展数据
                                            (if (eq Global:RvTXT "1") ;1标注文字,2不标文字
                                                (Rv:CreatRvTXT (atoi TXTCol) TmpDIM (list NewEn))
                                            )
                                        )
                                    )
                                    (setenv "K\\REVCLOUD-ArLen" (rtos Global:ArLen 2 1));储存最大弧长为环境变量
                                )
                            )
                        )
                        (setq HasGetRv T);点选生成云线后，空格不再提示选择对象
                        (if (eq Global:RvTXT "1");1标注文字,2不标文字
                            Nil ;退出循环
                            T ;继续循环
                        )
                      )
                      ((and (not HasGetRv) (or (equal Code '(2 13))(equal Code '(2 32))));回车+空格
                        (while (setq RvEn (car (Entsel "\n→请点选非锁对象<空格退出>: ")))
                            (if (eq 4 (logand 4 (cdr (assoc 70 (tblsearch "LAYER" (cdr (Assoc 8 (Entget RvEn))))))));图层锁定
                                (princ "\n——★★★ 所选对象图层已锁定!!! ★★★——\n")
                                (progn
                                    (setq EnType (cdr (Assoc 0 (Entget RvEn))))
                                    (if (member EnType (list "LINE" "ARC" "CIRCLE" "ELLIPSE" "POLYLINE" "LWPOLYLINE" "SPLINE" "INSERT" "ATTDEF" "TEXT" "MTEXT" "TCH_TEXT" "TCH_MTEXT" "TCH_DRAWINGNAME" "TCH_ELEVATION"))
                                        (progn
                                            (if 
                                                (or
                                                    (eq EnType "LINE");直线
                                                    (and (wcmatch EnType "*POLYLINE") (eq 0 (Cdr(Assoc 70 (entget RvEn)))));不闭合的多段线
                                                )
                                                (setq RvEn (Rv:GetOFFPL (Rv:GetTgtVxtLst RvEn) (atoi TmpCol)))
                                            )
                                            (if (member EnType (list "INSERT" "ATTDEF" "TEXT" "MTEXT" "TCH_TEXT" "TCH_MTEXT" "TCH_DRAWINGNAME" "TCH_ELEVATION"));文字取UCS包围盒
                                                (setq RvEn
                                                    (entmakeX 
                                                      (append 
                                                        (list 
                                                          '(0 . "LWPOLYLINE")
                                                          '(100 . "AcDbEntity")
                                                          '(100 . "AcDbPolyline")
                                                          '(90 . 4);顶点4
                                                          '(70 . 1);闭合多段线
                                                        )
                                                        (mapcar '(lambda (pt) (cons 10 (trans pt 1 0))) (apply 'K:GetRecPtLst (K:GetUCSBox RvEn)))
                                                      )
                                                    )
                                                )
                                            );更新使用外框
                                            (if (eq "1" Global:RvDyn);1静态
                                                (if
                                                  (and
                                                    (princ (strcat "\n——★★★ 推荐使用最大弧长为: " (rtos (Rv:RecSugArLen RvEn) 2 0)" ★★★——\n"))
                                                    (progn
                                                        (initget (+ 2 4) "D")
                                                        (setq TmpArLen ;设置弧长
                                                            (cond 
                                                              ((getreal (strcat  "\n→请输入最大弧长[临时动态(D)]: <"(rtos Global:ArLen 2 1)">")))
                                                              (Global:ArLen)
                                                            )
                                                        )
                                                    )
                                                  )
                                                  (if (= TmpArLen "D");字母D临时动态
                                                      (progn
                                                          (setq NewLst (Rv:DynCloudLine RvEn Nil)
                                                                NewEn (car NewLst)
                                                          )
                                                          (if NewEn
                                                              (progn
                                                                  (Rv:PutRvData NewEn);为对象添加扩展数据
                                                                  (if (eq Global:RvTXT "1") ;1标注文字,2不标文字
                                                                      (Rv:CreatRvTXT (atoi TXTCol) TmpDIM (list NewEn))
                                                                  )
                                                                  (setenv "K\\REVCLOUD-ArLen" (rtos Global:ArLen 2 1));储存最大弧长为环境变量
                                                              )
                                                          )
                                                      )
                                                      (progn
                                                        (setq Global:ArLen TmpArLen)
                                                        (while (> (getvar "CMDACTIVE") 0) (command PAUSE));等待前面的命令完成
                                                        (setq e0 (EntLast))
                                                        (command "_.REVCLOUD" "A" Global:ArLen Global:ArLen "O" RvEn "N");创建云线
                                                        (setq NewEn (EntNext e0))
                                                        (if NewEn
                                                            (progn
                                                                (Rv:PutRvData NewEn);为对象添加扩展数据
                                                                (if (eq Global:RvTXT "1") ;1标注文字,2不标文字
                                                                    (Rv:CreatRvTXT (atoi TXTCol) TmpDIM (list NewEn))
                                                                )
                                                            )
                                                        )
                                                        (setenv "K\\REVCLOUD-ArLen" (rtos Global:ArLen 2 1));储存最大弧长为环境变量
                                                      )
                                                  )
                                                )
                                                (progn
                                                  (setq NewLst (Rv:DynCloudLine RvEn Nil)
                                                        NewEn (car NewLst)
                                                        Global:ArLen (cadr NewLst)
                                                  )
                                                  (if NewEn
                                                      (progn
                                                          (Rv:PutRvData NewEn);为对象添加扩展数据
                                                          (if (eq Global:RvTXT "1") ;1标注文字,2不标文字
                                                              (Rv:CreatRvTXT (atoi TXTCol) TmpDIM (list NewEn))
                                                          )
                                                      )
                                                  )
                                                  (setenv "K\\REVCLOUD-ArLen" (rtos Global:ArLen 2 1));储存最大弧长为环境变量
                                                )
                                            )
                                        )
                                        (princ "\n——★★★ 请选择直线、圆弧、圆、椭圆、多段线、样条曲线、或文字！ ★★★——\n")
                                    )
                                )
                            )
                        )
                        (if (not RvEn)(princ "\n——★★★ 未选择对象，程序退出!!! ★★★——\n"))
                        Nil ;退出循环
                      )
                      ((or ;字母D
                        (eq (cadr Code) 68)
                        (eq (cadr Code) (+ 68 32))
                        )
                        (setq Global:RvDyn
                            (cond
                              ((eq "1" Global:RvDyn) "2")
                              ((eq "2" Global:RvDyn) "1")
                            )
                        );1静态,-1动态
                        (if (and 
                              (eq Global:RvDyn "1");1静态
                              (>= Global:ArLen 50)
                              (eq (getvar "TILEMODE") 0)
                              (eq (getvar "CVPORT") 1)
                            );布局空间
                            (setenv "K\\REVCLOUD-ArLen" (rtos (setq Global:ArLen 50) 2 1))
                        );布局空间静态弧长默认最大不超过50,避免模型动态转布局静态,弧长太大导致无法生成云线
                        T ;继续循环
                      )
                      ((or ;字母T
                        (eq (cadr Code) 84)
                        (eq (cadr Code) (+ 84 32))
                        )
                        (setq Global:RvTXT
                            (cond
                              ((eq "1" Global:RvTXT) "2")
                              ((eq "2" Global:RvTXT) "1")
                            )
                        );1标注文字,2不标文字
                        (if (and
                                (eq Global:RvTXT "1");标注文字
                                (progn
                                    (initget (+ 2 4)) ;非零非负关键词
                                    (setq TmpDIM 
                                        (cond
                                            ((getreal (strcat "\n→请输入标字比例或空格默认<" (rtos TmpDIM 2 1) ">")))
                                            (TmpDIM);空格回车使用上次的值
                                        )
                                    )
                                )
                            )
                            (if (and (eq (getvar "TILEMODE") 0)(eq (getvar "CVPORT") 1));布局空间
                                (setq Global:RvDIM (rtos TmpDIM 2 5));更新云线比例
                                (if (type (eval (read "TsetPScale")));存在天正命令
                                    (TsetPScale TmpDIM);设置天正比例
                                    (setq Global:RvDIM (rtos TmpDIM 2 5));更新云线比例
                                )
                            )
                        )
                        (K:SetGetData T "K\\RRSysNam" *MkVarLst*);用全局更新系统和黑板
                        T ;继续循环
                      )
                      ((and
                        (eq Global:RvTXT "1")
                        (or ;字母G
                          (eq (cadr Code) 71)
                          (eq (cadr Code) (+ 71 32))
                        )
                        )
                        (setq Global:RvSLa
                            (cond
                                ((eq "1" Global:RvSLa) "2")
                                ((eq "2" Global:RvSLa) "1")
                            )
                        );1字相同层,2字不同层
                        (K:SetGetData T "K\\RRSysNam" *MkVarLst*);用全局更新系统和黑板
                        T ;继续循环
                      )
                      ((or ;字母L
                        (eq (cadr Code) 76)
                        (eq (cadr Code) (+ 76 32))
                        )
                        (if LayFrz ;默认层冻结
                          (princ (strcat "\n——★★★ 默认层<"(car LayLst)">已冻结, 无法切换! ★★★——\n"))
                          (if (eq 4 (logand 4 (cdr (assoc 70 (tblsearch "LAYER" (if (eq "1" Global:RvLay) (cadr LayLst)(car LayLst)))))))
                              (princ (strcat "\n——★★★ 图层<" (if (eq "1" Global:RvLay) (cadr LayLst)(car LayLst)) ">已锁定, 无法切换! ★★★——\n"))
                              (progn
                                  (cond
                                      ((eq "1" Global:RvLay);1默认层,2当前层
                                          (setq Global:RvLay "2")
                                          (setvar "CLAYER" (cadr LayLst))
                                      )
                                      ((eq "2" Global:RvLay);1默认层,2当前层
                                          (setq Global:RvLay "1")
                                          (setvar "CLAYER" (car LayLst))
                                      )
                                  )
                                  (if (/= TmpCol (setq CurCol (rtos (Rv:Cecolor4ACI) 2 0)))
                                      (setq TmpCol CurCol)
                                  );避免使用RGB等颜色出错
                              )
                          )
                        )
                        T ;继续循环
                      )
                      ((or ;字母P
                        (eq (cadr Code) 80)
                        (eq (cadr Code) (+ 80 32))
                        )
                        (if (eq :vlax-true (vla-get-Plottable RvLayObj))
                            (vla-put-Plottable RvLayObj :vlax-false);不可打印
                            (vla-put-Plottable RvLayObj :vlax-true);可以打印
                        )
                        T ;继续循环
                      )
                      ((or ;字母R
                          (eq (cadr Code) 82)
                          (eq (cadr Code) (+ 82 32))
                        )
                        (setenv "K\\REVCLOUD-ArLen" (rtos (setq Global:ArLen 5) 2 1));最大弧长默认为5
                        (setq Global:RvTXT "2") ;1标注文字,2不标文字
                        (vla-put-color RvLayObj (distof (setq TmpCol "1")));图层颜色
                        (vla-put-Plottable RvLayObj :vlax-true);图层可打印
                        (entupd (tblobjname "layer" (if (eq "1" Global:RvLay)(car LayLst)(cadr LayLst))));刷新视图
                        (K:SetGetData T "K\\RRSysNam" *MkVarLst*);用全局更新系统和黑板
                        (princ (strcat  "\n——★★★ 云线最大弧长5MM、绘制后不标字、图层<" (if (eq "1" Global:RvLay)(car LayLst)(cadr LayLst)) ">红色且可打印 ★★★——\n"))
                        Nil ;退出循环
                      )
                      ((or ;字母S
                          (eq (cadr Code) 83)
                          (eq (cadr Code) (+ 83 32))
                        )
                        (princ "\n——★★★ 请选择需标注文字的直线、圆弧、圆、椭圆、多段线、样条曲线 ★★★——\n")
                        (while (setq SS (ssget ":L"))
                            (Rv:CreatRvTXT (atoi TXTCol) TmpDIM (K:SS->EntLst SS))
                            (princ "\n——★★★ 可继续选择直线、圆弧、圆、椭圆、多段线、样条曲线, 或空选退出 ★★★——\n")
                        )
                        Nil ;退出循环
                      )
                      ((or ;字母E
                          (eq (cadr Code) 69)
                          (eq (cadr Code) (+ 69 32))
                        )
                        (if 
                            (and
                                (princ "\n——★★★ 请选择云线程序标注的多行文字或空格全选 ★★★——\n")
                                (setq SS (ssget ":L" '((0 . "MTEXT")(-3 ("RvData")))));带扩展数据的多行文字
                            )
                            (Rv:Data2CSV SS);生成文件
                            (if (setq SS (ssget "A" '((0 . "MTEXT")(-3 ("RvData")))));带扩展数据的多行文字
                                (Rv:Data2CSV SS);生成文件
                                (alert "非冻结图层未收集到云线程序标注的多行文字！")
                            )
                        )
                        Nil ;退出循环
                      )
                      ((or ;字母B
                          (eq (cadr Code) 66)
                          (eq (cadr Code) (+ 66 32))
                        )
                        (while ;get*
                          (progn 
                            (initget "D A") ;关键词
                            (setq StaPT (getpoint (strcat "\n→请选择矩形的第一点[删除框叉(D)/视口全显全锁(A)]:")))
                            (cond 
                              ((and StaPT (eq (type StaPT) 'LIST));指定了点
                                  (if (setq DiaPT (getcorner StaPT "\n→请选择矩形的对角点:"))
                                      (Rv:DrawMkBox StaPT DiaPT (atoi TmpCol))
                                  )
                                  T ;继续循环
                              )
                              ((and (eq (type StaPT) 'STR)(eq (strcase StaPT) "D"));字母D
                                (princ "\n——★★★ 只选择云线程序创建的非锁框叉(输入ALL空格即可全选) ★★★——\n")
                                (while (setq SS (ssget ":L" '((0 . "LWPOLYLINE")(-3 ("MkBox")))));带扩展数据的线
                                    (repeat (setq i (sslength SS)) 
                                        (setq en (ssname SS (setq i (1- i))))
                                        (vla-Delete (vlax-ename->vla-object en))
                                    )
                                )
                                T ;继续循环
                              )
                              ((and (eq (type StaPT) 'STR)(eq (strcase StaPT) "A"));字母A
                                  (if (and (eq (getvar "TILEMODE") 0)(eq (getvar "CVPORT") 1))
                                      (progn
                                        (setq SSVP (ssget "X"(list '(0 . "VIEWPORT")(cons 410 (getvar "ctab")))))
                                        (repeat (setq i (sslength SSVP)) 
                                            (setq obj (vlax-ename->vla-object (ssname SSVP (setq i (1- i)))))
                                            (if (eq "AcDbViewport" (Vlax-Get obj 'ObjectName));是视口
                                                (progn
                                                    (vla-put-ViewportOn obj :vlax-true);视口显示
                                                    (vla-put-DisplayLocked obj :vlax-true);视口锁定
                                                )
                                            )
                                        );全显全锁
                                        (princ "\n——★★★ 当前空间内的视口已全显全锁 ★★★——\n")
                                        Nil ;退出循环
                                      )
                                      (progn
                                          (alert "请先回到布局空间!!!")
                                          ;(princ "\n——★★★ 请先回到布局空间！！ ★★★——\n")
                                          T ;继续循环
                                      )
                                  )
                              )
                            )
                          )
                        )
                        Nil ;退出循环
                      )
                      ((or ;字母C
                        (eq (cadr Code) 67)
                        (eq (cadr Code) (+ 67 32))
                        )
                        (if 
                            (and
                              (princ "\n——★★★ 请选择云线对象！ ★★★——\n")
                              (setq SS
                                  (ssget 
                                    '((-4 . "<and")
                                        (0 . "LWPOLYLINE")
                                        (-3 ("RvData"))
                                          (-4 . "<not")
                                          (-3 ("MkBox"))
                                          (-4 . "not>")
                                      (-4 . "and>")
                                    )
                                  );仅选云线
                              )
                            )
                            (Rv:ChgRandCol SS)
                        )
                        Nil ;退出循环
                      )
                      (T 
                          (if HasGetRv
                              (progn
                                  (princ "\n——★★★ 程序已安全退出！ ★★★——\n")
                                  Nil ;退出循环
                              )
                              (progn
                                  (princ "\n——★★★ 请输入正确的关键词或 ESC退出！ ★★★——\n")
                                  T ;继续循环
                              )
                          )
                      )
                    )
                  )
                )
              )
          )
          (if 
              (and
                (setq SS (ssget ":L"))
                (progn
                    (initget (+ 2 4) "A R N T C") ;非零非负关键词
                    (setq GetDIM 
                        (cond
                            ((getreal (strcat "\n→请输入标字比例或空格默认[旧云线归层(A)/移云线层(R)/移云不印层(N)/移文不印层(T)/随机色(C)]<" (rtos TmpDIM 2 1) ">")))
                            (TmpDIM);回车使用上次的值
                        )
                    )
                )
              )
              (cond 
                ((and GetDIM (eq (type GetDIM) 'Real))
                    (setq TmpDIM GetDIM)
                    (if (and (eq (getvar "TILEMODE") 0)(eq (getvar "CVPORT") 1));布局空间
                        (setq Global:RvDIM (rtos TmpDIM 2 5));更新云线比例
                        (if (type (eval (read "TsetPScale")));存在天正命令
                            (TsetPScale TmpDIM);设置天正比例
                            (setq Global:RvDIM (rtos TmpDIM 2 5));更新云线比例
                        )
                    )
                    (K:SetGetData T "K\\RRSysNam" *MkVarLst*);用全局更新系统和黑板
                    (Rv:CreatRvTXT (atoi TXTCol) TmpDIM (K:SS->EntLst SS))
                )
                ((and (eq (type GetDIM) 'STR)(eq (strcase GetDIM) "A"));字母A
                    (Rv:OldAutoLay SS)
                )
                ((and (eq (type GetDIM) 'STR)(eq (strcase GetDIM) "R"));字母R  
                    ;(command "chprop" SS "" "color" "bylayer" "ltype" "bylayer" "");将所选对象设置为随层
                    (Rv:MvtoLay SS (if (eq "1" Global:RvLay) (car LayLst) (cadr LayLst)))
                    (princ (strcat "\n——★★★ 所选对象已移至云线层<" (if (eq "1" Global:RvLay) (car LayLst) (cadr LayLst)) "> ★★★——\n")) 
                )
                ((and (eq (type GetDIM) 'STR)(eq (strcase GetDIM) "N"));字母N
                    (command "chprop" SS "" "color" "bylayer" "ltype" "bylayer" "");将所选对象设置为随层
                    (Rv:MvtoLay SS (caddr LayLst))
                    (princ (strcat "\n——★★★ 所选对象已移至云线不可打印层<" (caddr LayLst) "> ★★★——\n")) 
                )
                ((and (eq (type GetDIM) 'STR)(eq (strcase GetDIM) "T"));字母T
                    (command "chprop" SS "" "color" "bylayer" "ltype" "bylayer" "");将所选对象设置为随层
                    (Rv:MvtoLay SS (Last LayLst))
                  (princ (strcat "\n——★★★ 所选对象已移至文字不打印层<" (Last LayLst) "> ★★★——\n")) 
                )
                ((and (eq (type GetDIM) 'STR)(eq (strcase GetDIM) "C"));字母C
                    (Rv:ChgRandCol SS)
                )
              )
          )
      )
      (command "redraw")
      (K:SetGetData T "K\\RRSysNam" *MkVarLst*);更新或刷新程序参数
      (if LayFrz (setq Global:RvLay "1"));恢复默认图层
      (if *Old_SysVar* (foreach xx *Old_SysVar* (apply 'setvar xx)));参数恢复
    (vla-endundomark CurDoc) ;结束编组
    (princ)
)

(if (not (getenv "K\\ToolsIsExit"))
    (princ "\n——★★★ 绘制云线由Kucha开发，调用命令: RR ★★★——\n")
)(princ)


