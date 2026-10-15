
(if (null vlax-dump-object) (vl-load-com));将Visual LISP扩展功能加载到 AutoLISP
;Standard _DQ_None _DQ_Arrw

;全局变量说明：
;Global:AllDimSca 标注比例
;Global:DQ-BoxTol 分堆容差
;Global:DQ-DIMLay 图层是默认层PUB_DIM还是当前层
;Global:DQ-ArcMod 弧长半径标注方式
;Global:DQ-ArcDis 曲线起点偏移(默认是5倍)

;Global:DQ-FBlock：栏选时：是否计算块内对象交点, 和 Global:DQ-FHatch 共用
;Global:DQ-FHatch：栏选时：是否计算填充交点, 和 Global:DQ-FBlock 共用

(progn ;基础函数
  ;判断天正是否存在
  (defun DQ:HasTangent ()
      (and
          (equal (type (eval (read "TGetPScale"))) 'EXRXSUBR)
          (vl-every 
              '(lambda (XX) 
                (member (strcase XX) (mapcar 'strcase (arx)))
              )
              '("tch_kernal.arx" "Tch_PipeBase.arx" "tch_pipewire.arx")
          );三个插件都存在
      )
  )
  
  ;标注实体:PL+LWPL+LINE+ARC+Circle
  (defun DQ:Dim4Ent (TgtEn DIMSca ArcMod ArcDis / UCSzdir UCSAng EnType StaPT EndPT TgtPT PtLst Memb n en2)
    (setq UCSzdir (trans '(0 0 1) 1 0 T);UCS的Z方向,DXF210
          UCSAng (angle '(0 0 0)  (trans (getvar 'UCSXDIR) 0 UCSzdir));OCS的X轴线跟UCS的X轴夹角,DXF51
    ) 
    (setq ent (entget TgtEn)
          EnType (cdr (Assoc 0 (Entget TgtEn)))
    )
    (cond
        ((eq EnType "LINE") 
            (setq StaPT (K:GetDXF 10 ent) ;线段起点
                  EndPT (K:GetDXF 11 ent) ;线段终点
                  TgtPT (lambda (pt Dis) 
                              (mapcar '+ pt
                                  (MAT:v*s 
                                      (MAT:Rot2D (MAT:UnitVec (mapcar '- EndPT StaPT))(* PI 0.5));单位向量逆时针旋转90度
                                      Dis
                                  )
                              )
                         )       
            )

            (entmake 
              (list 
                (cons 0 "DIMENSION")
                (cons 100 "AcDbEntity")
                (cons 100 "AcDbDimension")
                (cons 51 (* -1 UCSAng))
                (cons 210 UCSzdir)
                (cons 3 "_DQ_Arch");标注样式
                (cons 10 (TgtPT EndPT (* DIMSca 5.0)));标注定义点

                (cons 70 1);对齐
                (cons 100 "AcDbAlignedDimension")
                (cons 13 StaPT);标注起点
                (cons 14 EndPT);标注终点

                (List -3
                  (List 
                    "ACAD"
                    '(1000 . "DSTYLE")
                    '(1002 . "{")
                    '(1070 . 40)(cons 1040 DIMSca);覆盖标注比例
                    '(1002 . "}")
                  )
                ) 
              )
            );CAD对齐标注
            
        )
        ((eq EnType "ARC")
            (setq PtLst (lambda (ent / nrm cen rad) 
                            (setq nrm (K:GetDXF 210 ent);法向
                                  cen (K:GetDXF 010 ent);圆心
                                  rad (K:GetDXF 040 ent);半径
                            )
                            (mapcar 
                                (function 
                                  (lambda (ang) 
                                    (trans (mapcar '+ cen (list (* rad (cos ang)) (* rad (sin ang)) 0.0)) nrm 0)
                                  )
                                )
                                (list (K:GetDXF 50 ent) (K:GetDXF 51 ent));起点和终点角度
                            )
                        )
                  TgtPT (lambda (pt Dis) 
                              (mapcar '+ pt
                                  (MAT:v*s 
                                      (MAT:Rot2D 
                                        (MAT:UnitVec (mapcar '- (car (PtLst ent)) (K:GetDXF 10 ent)))
                                        (/ (rem (+ (* pi 2) (- (K:GetDXF 51 ent) (K:GetDXF 50 ent))) (* pi 2)) 4)
                                      );单位向量逆时针旋转1/4
                                      Dis
                                  )
                              )
                          )
            );计算起点终点
            (if (/= 3 ArcMod)
                (entmake
                    (list 
                      (cons 0 "ARC_DIMENSION")
                      (cons 100 "AcDbEntity")
                      ;(cons 67 0)
                      (cons 100 "AcDbDimension")
                      (cons 10 (TgtPT (K:GetDXF 10 ent) (+ (K:GetDXF 40 ent) (* DIMSca ArcDis))));标注定义点
                      (cons 51 (* -1 UCSAng))
                      (cons 210 UCSzdir)
                      (cons 3 "_DQ_Arch");标注样式
                      (cons 100 "AcDbArcDimension")
                      (cons 13 (car (PtLst ent)));起点
                      (cons 14 (cadr (PtLst ent)));终点
                      (cons 15 (K:GetDXF 10 ent));圆心

                      (List -3
                        (List 
                          "ACAD"
                          '(1000 . "DSTYLE")
                          '(1002 . "{")
                          '(1070 . 40)(cons 1040 DIMSca);覆盖标注比例
                          '(1002 . "}")
                        )
                      ) 
                    )
                );CAD弧长标注
            )
            (while (> (getvar "CMDACTIVE") 0) (command PAUSE));等待前面的命令完成
            (if (/= 2 ArcMod)
                (entmake
                  (list
                    (cons 0 "DIMENSION")
                    (cons 100 "AcDbEntity")
                    (cons 62 6);洋红色
                    (cons 100 "AcDbDimension")
                    (cons 51 (* -1 UCSAng))
                    (cons 210 UCSzdir)
                    (cons 3 "_DQ_Arrw");标注样式
                    (cons 10 (K:GetDXF 10 ent));圆心坐标
                    (cons 11 (TgtPT (K:GetDXF 10 ent) (- (K:GetDXF 40 ent) (* DIMSca ArcDis))));文本基点

                    (cons 70 164);半径?
                    (cons 100 "AcDbRadialDimension")
                    (cons 15 (TgtPT (K:GetDXF 10 ent) (K:GetDXF 40 ent)));标注起点

                    (List -3
                        (List 
                          "ACAD"
                          '(1000 . "DSTYLE")
                          '(1002 . "{")
                          '(1070 . 40)(cons 1040 DIMSca);覆盖标注比例
                          '(1002 . "}")
                        )
                    )
                  )
                );CAD半径标注
            )
        )
        ((eq EnType "CIRCLE")
          (setq TgtPT (lambda (pt Dis) 
                            (mapcar '+ pt
                                (MAT:v*s 
                                    (MAT:Rot2D 
                                      (MAT:UnitVec (trans (list (K:GetDXF 40 ent) 0.0 0.0) 1 0))
                                      (/ PI 4)
                                    );单位向量逆时针旋转45度
                                    Dis
                                )
                            )
                        )   
          )
          (entmake
            (list
              (cons 0 "DIMENSION")
              (cons 100 "AcDbEntity")
              (cons 62 6);洋红色
              (cons 100 "AcDbDimension")
              (cons 51 (* -1 UCSAng))
              (cons 210 UCSzdir)
              (cons 3 "_DQ_Arrw");标注样式
              (cons 10 (TgtPT (K:GetDXF 10 ent) (- (K:GetDXF 40 ent))));标注终点
              (cons 11 (TgtPT (K:GetDXF 10 ent) (+ (K:GetDXF 40 ent) (* DIMSca 5.0))));文本基点

              (cons 70 163);直径
              (cons 100 "AcDbDiametricDimension")
              (cons 15 (TgtPT (K:GetDXF 10 ent) (K:GetDXF 40 ent)));标注起点

              (List -3
                  (List 
                    "ACAD"
                    '(1000 . "DSTYLE")
                    '(1002 . "{")
                    '(1070 . 40)(cons 1040 DIMSca);覆盖标注比例
                    '(1002 . "}")
                  )
              )
            )
          );CAD直径标注
        )
        ((eq EnType "LWPOLYLINE");轻多段线
            (redraw TgtEn 2);隐藏实体
            (foreach Memb (vlax-invoke (vlax-ename->vla-object TgtEn) 'Explode) 
                (setq en2 (vlax-vla-object->ename Memb))
                (DQ:Dim4Ent en2 DIMSca ArcMod ArcDis)
                (vla-Delete Memb)
            )
            (redraw TgtEn 1);显示实体
        )
        ((eq EnType "POLYLINE");重多段线
            (princ "\n——★★★ 不支持重多段线，请先使用CONVERTPOLY转为轻多段线! ★★★——\n")
            ;|
            (command "_.CONVERTPOLY" "L" TgtEn "");转换为轻
            (while (> (getvar "CMDACTIVE") 0) (command PAUSE));等待前面的命令完成
            (DQ:Dim4Ent TgtEn DIMSca ArcMod ArcDis)
            |;
        )
    )
  )
  ;通过UCS点表对齐标注
  (defun DQ:DIM4PtLst (WCSLst DIMSca / UCSzdir UCSAng StaPT EndPT TgtPT)
    (setq UCSzdir (trans '(0 0 1) 1 0 T);UCS的Z方向,DXF210
          UCSAng (angle '(0 0 0)  (trans (getvar 'UCSXDIR) 0 UCSzdir));OCS的X轴线跟UCS的X轴夹角,DXF51
    ) 
    (if (> (length WCSLst) 1)
        (progn
          (setq StaPT (car WCSLst) ;线段起点坐标
                EndPT (Last WCSLst) ;线段终点坐标
                TgtPT (lambda (pt Dis) 
                            (mapcar '+ pt
                                (MAT:v*s 
                                    (MAT:Rot2D (MAT:UnitVec (mapcar '- EndPT StaPT))(* PI 0.5));单位向量逆时针旋转90度
                                    Dis
                                )
                            )
                        )
          )

          (progn ;CAD两道标注
              (if (> (length WCSLst) 2)
                  (entmake
                    (list 
                      (cons 0 "DIMENSION")
                      (cons 100 "AcDbEntity")
                      (cons 100 "AcDbDimension")
                      (cons 51 (* -1 UCSAng))
                      (cons 210 UCSzdir)
                      (cons 3 "_DQ_Arch");标注样式
                      (cons 10 (TgtPT EndPT (* DIMSca 10.0)));标注定义点

                      (cons 70 1);对齐
                      (cons 100 "AcDbAlignedDimension")
                      (cons 13 StaPT);标注起点 
                      (cons 14 EndPT);标注终点

                      (List -3
                        (List 
                          "ACAD"
                          '(1000 . "DSTYLE")
                          '(1002 . "{")
                          '(1070 . 40)(cons 1040 DIMSca);覆盖标注比例
                          '(1002 . "}")
                        )
                      )
                    )
                  );CAD对齐标注
              );第二道总尺寸
              (while (> (length WCSLst) 1)
                  (entmake
                    (list 
                      (cons 0 "DIMENSION")
                      (cons 100 "AcDbEntity")
                      (cons 100 "AcDbDimension")
                      (cons 51 (* -1 UCSAng))
                      (cons 210 UCSzdir)
                      (cons 3 "_DQ_Arch");标注样式
                      (cons 10 (TgtPT (cadr WCSLst) (* DIMSca 5.0)));标注定义点

                      (cons 70 1);对齐
                      (cons 100 "AcDbAlignedDimension")
                      (cons 13 (car WCSLst));标注起点 
                      (cons 14 (cadr WCSLst));标注终点

                      (List -3
                        (List 
                          "ACAD"
                          '(1000 . "DSTYLE")
                          '(1002 . "{")
                          '(1070 . 40)(cons 1040 DIMSca);覆盖标注比例
                          '(1002 . "}")
                        )
                      )
                    )
                  );CAD对齐标注
                  (setq WCSLst (cdr WCSLst))
              );第一道标注
          )
        )
    )
  )

  ;新建图层：图层名称、图层颜色、是否打印(:vlax-false不打印，:vlax-true打印)
  (defun K:NLayNlock (LayNam Col Plt / TgtEn TgtObj) 
    ;若图层不存在则新建。若存在则检查图层和打印状态并解锁
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
  ;UCS两点获取四边形四点(并输出WCS点表)
  (defun K:RecLst4WCS (StaPT DiaPT / X1 x2 Y1 y2) 
    (setq X1 (max (car StaPT) (car DiaPT))
          x2 (min (car StaPT) (car DiaPT))
          Y1 (max (cadr StaPT) (cadr DiaPT))
          y2 (min (cadr StaPT) (cadr DiaPT))
    )
    (if (or (equal X1 x2 1e-6) (equal Y1 Y2 1e-6))
        (list (trans StaPT 1 0) (trans DiaPT 1 0));2个
        (mapcar
          (function (lambda (XX) (trans XX 1 0) ));WCS
          (list
              (list x2 y2);左下
              (list x2 Y1);左上
              (list X1 Y1);右上
              (list X1 y2);右下   
          )
        )
    )
  )
)
(progn ;边界框函数
  ;WCS下实体或对象最小边界框的WCS坐标(左下角和右上角)@Gu_xl
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
  ;UCS下实体或对象最小边界框的UCS坐标(左下角和右上角)@Kucha
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
  ;获取选择集所有实体的最小边界框表(WCS/UCS)@Kucha
  (defun K:SSAllBoxLst (WCS TgtSS / i en SSBox) 
      (if TgtSS 
          (repeat (setq i (sslength TgtSS)) 
            (setq en (ssname TgtSS (setq i (1- i))))
            (setq SSBox 
                  (cons 
                    (if WCS (K:GetWCSBox en) (K:GetUCSBox en))
                    SSBox
                  )
            )
          )
      )
      SSBox
  )
  ;获取选择集的最小边界框(WCS/UCS)@Kucha
  (defun K:SSMinBoxLst (WCS TgtSS / i en Box BoxMin BoxMax MinPt MaxPt) 
      (if TgtSS
          (repeat (setq i (sslength TgtSS)) 
              (setq en (ssname TgtSS (setq i (1- i))))
              (setq Box (if WCS (K:GetWCSBox en) (K:GetUCSBox en)))
              (setq BoxMin (car Box) BoxMax (cadr Box))
              (setq MinPt (mapcar 'min BoxMin (cond (MinPt) (BoxMin))))
              (setq MaxPt (mapcar 'max BoxMax (cond (MaxPt) (BoxMax))))
          )
      )
      (list MinPt MaxPt)
  )
  ;矩形分组(矩形分堆),并返回每一个组的包围盒@Tryhi-大海(优化 by Kucha)
  (defun K:RtnBox4Group (RecLst Gap SpcTol / K:2RecInters NewLst TmpLst Flag RdoLst BasRec FstRec IntRec a b)
    ;时间复杂度为n(1)，测试了17万个图元480组仅10秒
    
    ;如果矩形相交，则返回两矩形的最大边界框
    (defun K:2RecInters (Fst Sec)
      (if 
        (not 
          (or  ;不可能重叠的四种情况
            (> (car Fst) (caddr Sec)) ;A的左侧比B的右侧大：X
            (> (cadr Fst) (Last Sec)) ;A的下部比B的上部大：Y
            (< (caddr Fst) (car Sec)) ;A的右侧比B的左侧小：X
            (< (Last Fst) (cadr Sec)) ;A的上部比B的下部小：Y
          )
        )
        (list 
          (min (car Fst) (car Sec))
          (min (cadr Fst) (cadr Sec))
          (max (caddr Fst) (caddr Sec))
          (max (Last Fst) (Last Sec))
        )
      )
    )
    (if (and RecLst  (setq Gap (/ Gap 2)))
        (progn 
            (setq RecLst
                (mapcar 
                  '(lambda (XX) 
                      (list 
                          (nth 0 (car XX)) (nth 1 (car XX))
                          (nth 0 (cadr XX)) (nth 1 (cadr XX))
                      )
                  )
                  RecLst
                )
            );只取XY合并组成新的表,排序时再调整回来
            (setq RecLst (mapcar '(lambda (XX) (mapcar '+ XX (list (- Gap) (- Gap) Gap Gap))) RecLst));矩形扩大
            (progn ;合并矩形
              (setq Flag T RdoLst Nil)
              (while Flag 
                (setq BasRec (car RecLst) NewLst Nil)
                (while (car RecLst) ;主要耗时点
                  (setq RecLst (cdr RecLst)) ;更新列表
                  (if (setq IntRec (K:2RecInters BasRec (setq FstRec (car RecLst)))) 
                    (setq BasRec IntRec);RecLst中有和BasRec相交的矩形,更新BasRec
                    (if 
                      (setq TmpLst (vl-some 
                                '(lambda (a / b) 
                                    (if (setq b (K:2RecInters BasRec a))
                                      (list b a)
                                    )
                                  )
                                NewLst
                              )
                      );NewLst中有和BasRec相交的矩形
                      (progn 
                        (if (not (eq (car TmpLst) (Last TmpLst)))
                            (setq NewLst (subst (car TmpLst) (Last TmpLst) NewLst))
                        );相交矩形和表中对应元素不同则替换
                        (setq BasRec FstRec)
                      )
                      (setq NewLst (cons BasRec NewLst)
                            BasRec FstRec
                      );收集并更新
                    )
                  )
                )
                (if (eq (length NewLst) (length RdoLst)) 
                  (setq Flag Nil)
                  (setq RdoLst NewLst 
                        RecLst NewLst
                  )
                )
              )
            )
            (setq NewLst (mapcar '(lambda (XX) (mapcar '+ XX (list Gap Gap (- Gap) (- Gap)))) NewLst));矩形缩小
            (vl-sort 
              (mapcar 
                '(lambda (x) 
                      (list 
                        (list (car x) (cadr x)) 
                        (list (caddr x) (cadddr x))
                      )
                  )
                NewLst
              );重新调整LST表的数据结构
              '(lambda (a b) 
                  (if (equal (cadr (car a)) (cadr (car b)) SpcTol)  ;Y在容差内相等？
                      (if (equal (car (car a)) (car (car b)))  ;X相等
                        (> (cadr (car a)) (cadr (car b))) ;比较Y
                        (< (car (car a)) (car (car b))) ;比较X
                      )
                      (> (cadr (car a)) (cadr (car b))) ;比较Y
                  )
                )
            );重新排序:先上下后左右
        )
    );矩形分堆得到互不相交的矩形LST
  )
)
(progn ;交点与栏选
  ;收集对象和对象的交点@MenziEngineeringGmbh
  (defun K:VxGetInters (WCS Fst Nxt Mde / K:LstGroup4Num TmpLst PtLst) 
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
    (if (eq 'ENAME (type Fst))(setq Fst (vlax-ename->vla-object Fst)))
    (if (eq 'ENAME (type Nxt))(setq Nxt (vlax-ename->vla-object Nxt)))
    (if (setq TmpLst (vlax-invoke Fst 'INTERSECTWITH Nxt Mde))
        (setq PtLst 
            (if WCS
                (K:LstGroup4Num TmpLst 3)
                (mapcar '(lambda (XX) (trans XX 0 1)) (K:LstGroup4Num TmpLst 3))
            )
        )
    )
    PtLst
  )
  ;收集对象和块的交点@MenziEngineeringGmbh
  (defun K:VxGetBLKinters (WCS Obj Blk Mde HFlag / XX TmpLst ObjNam PtLst *LockLst*)
    (if (eq 'ENAME (type Obj))(setq Obj (vlax-ename->vla-object Obj)))
    (if (eq 'ENAME (type Blk))(setq Blk (vlax-ename->vla-object Blk)))
    (foreach XX (vlax-invoke Blk 'EXPLODE)
      (setq ObjNam (vla-get-objectname XX)
            LayObj (vlax-ename->vla-object (tblobjname "layer" (vla-get-Layer XX)))
      )
      (if (eq (vla-get-lock LayObj) :vlax-true);锁定了
          (progn 
            (setq *LockLst* (cons LayObj *LockLst*))
            (vla-put-lock LayObj :vlax-false);解锁
          )
      )
      (cond 
        ((or 
            (not (vlax-method-applicable-p XX 'INTERSECTWITH));不可使用交点算法
            (and 
              (eq ObjNam "AcDbHatch")
              (eq (strcase (vla-get-patternname XX)) "SOLID")
            );实体填充
            (eq ObjNam "AcDb3dSolid");三维实体
          )
        )
        ((eq ObjNam "AcDbBlockReference");块参照
          (if (setq TmpLst (K:VxGetBLKinters WCS Obj XX Mde HFlag)) 
              (setq PtLst (append PtLst TmpLst))
          )
        )
        (T
          (if 
              (or
                  (member ObjNam '("AcDbLine" "AcDbPolyline" "AcDb2dPolyline" "AcDbArc" "AcDbCircle"))
                  (and (eq HFlag 1)(eq ObjNam "AcDbHatch"))
              )
              (if (setq TmpLst (K:VxGetInters WCS Obj XX Mde))
                  (setq PtLst (append PtLst TmpLst))
              )
          )
        )
      )
      (vla-delete XX)
    )
    (if *LockLst* (foreach XX *LockLst* (vla-put-lock XX :vlax-true)));再锁定
    PtLst
  )
  ;收集在线段P1P2上的所有对象端点WCS坐标
  (defun K:WCSPt4Line (TgtSS WcsPT1 WcsPT2 / PtLst)
    (setq PtLst '());清空列表
    (repeat (setq i (sslength TgtSS))
      (setq en     (ssname TgtSS (setq i (1- i)))
            obj    (vlax-ename->vla-object en)
      )
      (if (member (cdr (assoc 0 (entget en))) (list "LINE" "POLYLINE" "LWPOLYLINE"))
          (setq PtLst 
              (append 
                  (list 
                    (vlax-curve-getstartpoint obj)
                    (vlax-curve-getendpoint obj)
                  );WCS
                  PtLst
              )
          )
      )
    );收集端点坐标
    (vl-remove-if-not 
      '(lambda (pt) 
        (equal 
            (distance WcsPT1 WcsPT2)
            (+ (distance pt WcsPT1) (distance pt WcsPT2))
            1e-6
        )
      )
      PtLst
    );过滤掉不在直线上的端点
  )
  ;删除列表中重复的元素(容差)@LEEMAC
  (defun K:UniqueFuzz (Lst Fuzz) 
    (if Lst 
      (cons 
        (car Lst)
        (K:UniqueFuzz 
          (vl-remove-if 
            (function (lambda (x) (equal x (car Lst) Fuzz)))
            (cdr Lst)
          )
          Fuzz
        )
      )
    )
  )
)
(progn ;连续标注/合并标注/标注比例
    (progn ;基础函数
        ;取Key对应的值
        (defun K:GetDXF (Key ent) (cdr (assoc Key ent)))

        ;选择集转实体表@Lee Mac
        (defun K:SS->EntLst (TgtSS / i en EntLst) 
          (if TgtSS 
            (repeat (setq i (sslength TgtSS)) 
              (setq en (ssname TgtSS (setq i (1- i))))
              (setq EntLst (cons en EntLst))
            )
          )
        )
        ;求3点逆时针角度(p0为角点)
        (defun K:3ptsAng-CW (p0 p1 p2 / ans a b) 
          (setq ans (list (angle p1 p0) (angle p2 p0))
                a   (apply 'min ans)
                b   (apply 'max ans)
          )
          (if (= a (car ans)) 
            (- b a)
            (- (* 2 PI) (- b a))
          )
        )
        ;判断两个标注是否相同(对齐+弧长)
        (defun K:IsComDim (ArcDim en1 en2 / ent1 ent2 PXCal TXCal NormCal) 
            (setq PXCal 
                  (lambda (v1 v2) (equal (apply '+ (MAT:Cross (MAT:UnitVec v1) (MAT:UnitVec v2))) 0.0 1e-6));两单位向量平行
            )
            (setq TXCal 
                  (lambda (v1 v2) (< (abs (- (MAT:Dot v1 v2)(* (MAT:norm v1) (MAT:norm v2)))) 1e-6));同向：点积等于模长乘积（浮点误差<1e-6）
            )
            (setq NormCal
                  (lambda (v1 v2) (< (abs (- (MAT:norm v1) (MAT:norm v2))) 1e-6));向量模相等
            )
            (if (/= en1 en2)
                (progn
                    (setq ent1  (entget en1)
                          ent2  (entget en2)
                    )
                    (if ArcDim
                        (and
                            (equal
                                (vla-get-ScaleFactor (vlax-ename->vla-object en1))
                                (vla-get-ScaleFactor (vlax-ename->vla-object en2))
                                1e-6
                            );标注比例相等
                            (< (apply '+ (mapcar '- (K:GetDXF 15 ent1) (K:GetDXF 15 ent2))) 1e-6);圆心相等
                            (vl-catch-all-apply 'NormCal
                                (list 
                                  (mapcar '- (K:GetDXF 13 ent1) (K:GetDXF 15 ent1))
                                  (mapcar '- (K:GetDXF 13 ent2) (K:GetDXF 15 ent2))
                                );起点到圆心的长度相等
                            )
                            (vl-catch-all-apply 'NormCal
                                (list 
                                  (mapcar '- (K:GetDXF 10 ent1) (K:GetDXF 15 ent1))
                                  (mapcar '- (K:GetDXF 10 ent2) (K:GetDXF 15 ent2) )
                                );定义点到圆心的长度相等
                            )
                        )
                        (and
                            (equal
                                (vla-get-ScaleFactor (vlax-ename->vla-object en1))
                                (vla-get-ScaleFactor (vlax-ename->vla-object en2))
                                1e-6
                            );标注比例相等
                            (vl-catch-all-apply 'PXCal
                                (list 
                                  (mapcar '- (K:GetDXF 13 ent1) (K:GetDXF 14 ent1))
                                  (mapcar '- (K:GetDXF 13 ent2) (K:GetDXF 14 ent2))
                                );起点终点平行
                            )
                            (vl-catch-all-apply 'PXCal
                                (list 
                                  (mapcar '- (K:GetDXF 13 ent1) (K:GetDXF 14 ent1))
                                  (mapcar '- (K:GetDXF 10 ent1) (K:GetDXF 10 ent2))
                                );定义点平行
                            )
                        )
                    )
                )
                nil
            )
        )
        ;获取当前视口内的相同标注(对齐或弧长)
        ;(K:GetComDim (ssname (ssget ":S:E") 0))
        (defun K:GetComDim (Tgten / Sub:GetViewXY RtnLst ent ViewBox ArcDim SSF OriSS TmpLst Flag Lst1 Lst2 ) 
            ;获取视口的WCS坐标
            (defun Sub:GetViewXY (/ vc vh vs) 
              (setq vc (trans (getvar "viewctr") 1 2);中心点
                    vh (getvar "viewsize");高度
                    vs (mapcar '/ (list (* (apply '/ (getvar "screensize")) vh) vh) '(2 2))
              )
              (mapcar '(lambda (f) (trans (mapcar f vc vs) 2 1)) '(- +))
            )

            (setq RtnLst  nil
                  ent     (Entget Tgten)
                  ViewBox (Sub:GetViewXY)
            )
            (cond
              ((eq (Cdr (Assoc 0 ent)) "ARC_DIMENSION");弧长标注
                (setq SSF (list (cons 0 "ARC_DIMENSION")))
                (setq ArcDim T)
              )
              ((and (eq (Cdr (Assoc 0 ent)) "DIMENSION") (member (Cdr (Assoc 70 ent)) (list 1 33 65 161)));对齐标注
                  (setq SSF
                      (append 
                          (list
                            (cons 0 "DIMENSION")
                            (cons -4 "<OR")
                          )
                          (mapcar (function (lambda (XX) (cons 70 XX)))(list 1 33 65 161))
                          (list (cons -4 "OR>"))
                      )
                  )
                  (setq ArcDim Nil)
              )
              (T (setq SSF Nil))
            )

            (if (and SSF (setq OriSS (ssget "C" (car ViewBox) (Last ViewBox) SSF)));选对齐标注/弧长标注
                (if (= 1 (sslength OriSS)) 
                    (setq RtnLst (list (ssname OriSS 0)))
                    (progn 
                        (setq TmpLst (list (list (K:GetDXF 13 (entget Tgten)) (K:GetDXF 14 (entget Tgten)) Tgten)))
                        (foreach XX (vl-remove Tgten (K:SS->EntLst OriSS))
                            (if (K:IsComDim ArcDim Tgten XX)
                                (setq TmpLst  
                                       (cons 
                                         (list (K:GetDXF 13 (entget XX)) (K:GetDXF 14 (entget XX)) XX)
                                         TmpLst
                                       )
                                )
                            )
                        );收集方向相同的标注

                        (setq RtnLst nil
                              Lst1  (list (car (last TmpLst)) (cadr (last TmpLst))) ;起点终点
                        )
                        (while 
                          (progn 
                              (foreach XX TmpLst 
                                  (if 
                                      (and
                                          (vl-some '(lambda (p) 
                                                        (or 
                                                          (equal (car XX) p 1e-6)
                                                          (equal (cadr XX) p 1e-6)
                                                        )
                                                    )
                                            Lst1
                                          );点
                                      )
                                      (setq RtnLst (cons (last XX) RtnLst);收集实体
                                            Lst1 (vl-list* (car XX) (cadr XX) Lst1)
                                            Flag t
                                      )
                                      (setq Lst2 (cons XX Lst2))
                                  )
                              )
                              Flag
                          )
                          (setq TmpLst Lst2
                                Lst2 nil
                                Flag nil
                          )
                        );链选

                    )
                )
                ;(command "RECTANG" (trans (car ViewBox ) 0 1) (trans (cadr ViewBox ) 0 1))
            )
            RtnLst
        )
        ;匿名函数：计算现有对齐标注和弧长的点表
        (setq CalDIM_Pts 
            (lambda (enLst ArcDim)
                ;ent CenPT End-CCW TgtDis StaPT EndPT Uvec CalDim_Dis PTLst NenLst
                (setq NenLst enLst)
                (setq ent (entget (car NenLst)))
                (if ArcDim
                    (progn
                        (setq CenPT (K:GetDXF 15 ent);圆心
                              TgtDis (distance CenPT (K:GetDXF 10 ent))
                              End-CCW (eq -1
                                          (MAT:ChkPtsCCW 
                                                (list
                                                  (mapcar '- (K:GetDXF 13 ent) CenPT)
                                                  (mapcar '- (K:GetDXF 10 ent) CenPT)
                                                  (mapcar '- (K:GetDXF 14 ent) CenPT)
                                                )
                                          )
                                      );14在逆时针
                        )
                        (if End-CCW ;14在逆时针方向
                            (setq   StaPT (K:GetDXF 13 ent);起点
                                    EndPT (K:GetDXF 14 ent);终点
                            )
                            (setq   StaPT (K:GetDXF 14 ent);起点
                                    EndPT (K:GetDXF 13 ent);终点
                                    End-CCW (not End-CCW)
                            )
                        );EndPT始终在逆时针方向
                        (setq CalDim_Dis 
                            (lambda (TgtPT / Tgt-CCW Tgt-Ang Tgt-Var) 
                                (setq Tgt-Ang (K:3ptsAng-CW CenPT StaPT TgtPT)
                                      Tgt-CCW (< Tgt-Ang (+ pi (* 0.5 (K:3ptsAng-CW CenPT StaPT EndPT))))
                                );TgtPT在逆时针方向
                                (setq Tgt-Var (* (if Tgt-CCW Tgt-Ang (- (* 2 pi) Tgt-Ang))(* 0.5 (distance CenPT StaPT))));圆心角对应的弧长=圆心角*圆弧半径
                                (setq Tgt-Var (if (and End-CCW Tgt-CCW) (* -1 Tgt-Var) Tgt-Var));同向*-1，排在前面
                            )
                        );计算距离
                    )
                    (setq TgtDis (distance (K:GetDXF 14 ent) (K:GetDXF 10 ent))
                          StaPT (K:GetDXF 13 ent);起点
                          EndPT (K:GetDXF 14 ent);终点

                          Uvec (MAT:UnitVec (mapcar '- EndPT StaPT))
                          CalDim_Dis (lambda (TgtPT) (MAT:Dot (mapcar '- TgtPT StaPT) Uvec))   
                    )
                )
                (progn ;共用
                    (setq PtLst (list (list StaPT 0.0)(list EndPT (CalDim_Dis EndPT))));收集起点终点及投影距离

                    (if (> (length NenLst) 1)
                        (foreach XX (cdr NenLst)
                            (setq ent (entget XX))
                            (foreach PerPT (list (K:GetDXF 13 ent) (K:GetDXF 14 ent))
                                (if
                                    (not
                                        (or
                                            (apply 
                                                'and
                                                (mapcar '(lambda (a b) (equal a b 1e-6))
                                                    PerPT StaPT
                                                )
                                            )
                                            (apply 
                                                'and
                                                (mapcar '(lambda (a b) (equal a b 1e-6))
                                                    PerPT EndPT
                                                )
                                            )
                                        )
                                    );点不是起点/终点
                                    (progn
                                        (setq TmpVar (CalDim_Dis PerPT))
                                        (if (not (vl-some (function (lambda (xx) (equal (cadr xx) TmpVar 1e-1))) PtLst));点不存在
                                            (setq PTLst (cons (list PerPT TmpVar) PTLst));目标点加入总表
                                        )
                                    )
                                )


                            )
                        )
                    );大于1个才收集其它的信息
                  
                    (repeat (1- (- (length PTLst) (length NenLst)))
                        (command ".copy" (car NenLst) "" "" "");原位复制标注
                        (command ".dimedit" "_h" (entlast) "")
                        (setq NenLst (cons (entlast) NenLst));收集实体
                    );处理尺寸重合缺少实体的情况
                )
                (setq PtLst (vl-sort PtLst (function (lambda (a b)(< (cadr a) (cadr b))))));按投影距离排序(负在前，正在后)
            )
        )
    )
    ;连续标注对齐标注/弧长
    (defun K:DIM4EnLst (ArcDim enLst / ent CenPT End-CCW TgtDis StaPT EndPT Uvec CalDim_Dis PTLst NenLst
                          UCSPT PerPT TmpVar ComDim i Nent OutPT Went) 
        (if enLst
          (progn 
              (CalDIM_Pts enLst ArcDim)
              (while (setq UCSPT (getpoint "\n→请指定插入点:"));UCS
                  (setq PerPT
                        (if ArcDim 
                          (mapcar '(lambda (a b) (+ (* a (distance StaPT CenPT )) b))
                              (MAT:UnitVec (mapcar '- (trans UCSPT 1 0) CenPT))
                              CenPT ;起点
                          );WCS(投影到圆弧上)
                          (MAT:PT2Line (trans UCSPT 1 0) StaPT EndPT);WCS(投影到线上)
                      )
                  )
                  (setq TmpVar (CalDim_Dis PerPT))
                  (if (vl-some (function (lambda (xx) (equal (cadr xx) TmpVar 1e-6))) PtLst);点存在
                      (princ "\n——★★★ 所选点已使用，请重新选择！ ★★★——\n")
                      (progn
                          (command ".copy" (car NenLst) "" "" "");原位复制标注
                          (command ".dimedit" "_h" (entlast) "")
                          (setq NenLst (cons (entlast) NenLst));收集实体
                          (setq PTLst (cons (list PerPT TmpVar) PTLst));目标点加入总表
                          (setq ComDim (vl-sort PtLst (function (lambda (a b)(< (cadr a) (cadr b))))));按投影距离排序(负在前，正在后)

                          (setq i 0)
                          (while (> (length ComDim) 1) 
                              (setq Nent (entget (nth i NenLst)))
                              (setq OutPT
                                    (if ArcDim
                                        (mapcar '+ CenPT
                                            (MAT:v*s 
                                                (MAT:Rot2D 
                                                    (MAT:UnitVec (mapcar '- (caadr ComDim) CenPT))
                                                    (* 0.5 (K:3ptsAng-CW CenPT (caadr ComDim) (caar ComDim)))
                                                );单位向量逆时针旋转
                                                TgtDis
                                            )
                                        )
                                        nil
                                    )
                              )
                              
                              (setq Went (subst (cons 13 (caar ComDim)) (assoc 13 Nent) Nent) ;起点
                                    Went (subst (cons 14 (caadr ComDim)) (assoc 14 Went) Went) ;终点
                              )
                              (if OutPT (setq Went (subst (cons 10 OutPT) (assoc 10 Went) Went))) ;更新定义点
                            
                              (entmod Went)

                              (setq i      (1+ i)
                                    ComDim (cdr ComDim)
                              )
                          )
                      )
                  )
              )
          )
        )
    )

    ;标注合并功能
    (defun K:MergeDim (SS / LineLst ArcLst i en ent En2Grp) 
        (setq En2Grp
            (lambda (enLst ArcDim /
                            ent CenPT End-CCW TgtDis StaPT EndPT Uvec CalDim_Dis PTLst NenLst
                            GenLst GrpLst BseEn ComDim TmpLst FstEn i Went
                        )
                (setq GrpLst '() CSLst '());清空表
                (while (setq BseEn (car enLst)) 
                    (setq enLst (cdr enLst))
                    (setq ComDim '()
                          ComDim (cons BseEn ComDim);收集第一个实体
                          CSLst (cons BseEn CSLst)
                    )
                    (setq TmpLst enLst)
                    (while (setq FstEn (car TmpLst)) 
                        (if (and
                                (K:IsComDim ArcDim BseEn FstEn)
                            )
                            (setq ComDim (cons FstEn ComDim) ;是同一个标注则收集
                                  enLst  (vl-remove FstEn enLst) ;然后从表中删除对应实体
                            )
                        )
                        (setq TmpLst (cdr TmpLst))
                    )
                    (setq GrpLst (cons ComDim GrpLst))
                )
                
                (repeat (setq i (length GrpLst))
                    (setq enLst (nth (setq i (1- i)) GrpLst))
                    (if (>= (length enLst) 2);至少有2个才会合并
                        (progn
                            (CalDIM_Pts enLst ArcDim)
                            (setq ent  (entget (car NenLst))
                                  Went (subst (cons 13 (car (car PtLst))) (assoc 13 ent) ent) ;起点
                                  Went (subst (cons 14 (car (Last PtLst))) (assoc 14 Went) Went) ;终点
                            )
                            (entmod Went)
                            
                            (foreach XX (cdr NenLst)
                                (vla-Delete (vlax-ename->vla-object XX)) 
                            );删除多余的实体
                        )
                    )
                )
            )
        );分组并合并
      
        (setq LineLst Nil ArcLst Nil);清空变量
        (command ".dimedit" "_h" SS "");文字复位
        (repeat (setq i (sslength SS)) 
            (setq en  (ssname SS (setq i (1- i)))
                  ent (entget en)
            )
            (cond
                ((eq (Cdr (Assoc 0 ent)) "ARC_DIMENSION");弧长标注
                    (setq ArcLst (cons en ArcLst))
                )   
                ((and (eq (Cdr (Assoc 0 ent)) "DIMENSION") (member (Cdr (Assoc 70 ent)) (list 1 33 65 161)));对齐标注
                    (setq LineLst (cons en LineLst))
                )
            )
        );对象收集
        (En2Grp LineLst Nil)
        (En2Grp ArcLst T)
    )
    ;说明:标注避让函数
    ;参数:	(MrAbu:dimadjust SS)
    (defun MrAbu:dimadjust (TgtSS / MrAbu-dxf MrAbu-perpt MrAbu-chgent n m ent en ang w h l_dat l_mov oldang mov s pt pt1 
                            pt2 l_adj en l_en disang disw dish item item1
                          ) 
      (progn 
        (defun MrAbu-dxf (en n) 
          (if (not (listp en)) (setq en (entget en)))
          (cdr (assoc n en))
        )
        (defun MrAbu-perpt (pt pt1 pt2) 
          (inters pt1 pt2 pt (polar pt (+ (angle pt1 pt2) (/ pi 2)) 1200) nil)
        )
        (defun MrAbu-chgent (en n / m val) 
          (if (not (listp en)) (setq en (entget en)))
          (foreach itm n 
            (setq m   (car itm)
                  val (cadr itm)
            )
            (if (assoc m en) 
              (setq en (subst (cons m val) (assoc m en) en))
              (setq en (append en (list (cons m val))))
            )
          )
          (entmod en)
        )
      )
      (if TgtSS 
        (progn 
          (vl-cmdf "_undo" "_be")
          (vl-cmdf "_.dimedit" "_h" TgtSS "")
          (setq n -1
                m 0
          )
          (repeat (sslength TgtSS) 
            (setq ent (ssname TgtSS (setq n (1+ n))))
            (setq en (MrAbu-dxf (tblsearch "block" (MrAbu-dxf ent 2)) -2))
            (while (/= (MrAbu-dxf (setq en (entnext en)) 0) "MTEXT"))
            (setq ang (MrAbu-dxf en 50)
                  h   (MrAbu-dxf en 43)
                  w   (+ (/ (MrAbu-dxf en 42) 2) (* 0.2 h))
                  h   (* 0.6 h)
            )
            (setq l_dat (cons (list ent ang w h) l_dat))
            (if (< (/ (MrAbu-dxf ent 42) 2) w) 
              (if (= (rem (setq m (1+ m)) 2) 0) 
                (setq l_mov (cons (list ent ang w h) l_mov))
                (setq l_mov (append l_mov (list (list ent ang w h))))
              )
            )
          )
          (foreach itm l_mov 
            (setq ent    (car itm)
                  ang    (cadr itm)
                  w      (caddr itm)
                  h      (cadddr itm)
                  pt     (MrAbu-dxf ent 11)
                  oldang (angle pt (MrAbu-perpt pt (setq pt1 (MrAbu-dxf ent 10)) (polar pt1 ang 1200)))
                  mov    T
            )
            (while 
              (and 
                mov
                (setq s (ssget 
                          "_f"
                          (list 
                            (setq pt1 (polar (polar pt ang w) (+ ang (/ pi 2)) h))
                            (setq pt2 (polar pt1 (+ ang pi) (* 2 w)))
                            (setq pt2 (polar pt2 (- ang (/ pi 2)) (* 2 h)))
                            (polar pt2 ang (* 2 w))
                            pt1
                          )
                          '( 
                            (0 . "DIMENSION")
                            (100 . "AcDbAlignedDimension")
                          )
                        )
                )
              )
              (setq n     -1
                    l_adj nil
              )
              (repeat (sslength s) 
                (setq en (ssname s (setq n (1+ n))))
                (if 
                  (and 
                    (ssmemb en TgtSS)
                    (not (equal en ent))
                    (setq l_en (MrAbu-dxf l_dat en))
                    (equal ang (car l_en) 0.01)
                  )
                  (progn 
                    (setq pt1    (MrAbu-perpt (MrAbu-dxf en 11) pt (polar pt ang 1200))
                          disang (angle pt1 pt)
                          disw   (- (+ w (cadr l_en)) (distance pt pt1))
                          dish   (- 
                                  (+ h (caddr l_en))
                                  (distance pt (MrAbu-perpt (MrAbu-dxf en 11) pt (polar pt (+ ang (/ pi 2)) 1200)))
                                )
                    )
                    (if (and (> dish 0) (not (equal dish 0 1))) 
                      (if (setq item (vl-member-if '(lambda (e) (equal (car e) disang 0.01)) l_adj)) 
                        (setq item  (car item)
                              l_adj (subst (list disang (max disw (cadr item)) (max dish (caddr item))) item l_adj)
                        )
                        (setq l_adj (cons (list disang disw dish) l_adj))
                      )
                    )
                  )
                )
              )
              (cond 
                ((not l_adj) (setq mov nil))
                ((and 
                  (= (length l_adj) 1)
                  (setq item (car l_adj))
                  (> (setq disw (cadr item)) 0)
                  (not (equal disw 0 1))
                  (> (caddr item) 0)
                )
                (if (> (MrAbu-dxf ent 70) 128) 
                  (progn 
                    (setq pt1 (MrAbu-perpt pt (setq pt2 (MrAbu-dxf ent 10)) (polar pt2 ang 1200)))
                    (MrAbu-chgent 
                      ent
                      (list 
                        (list 
                          11
                          (setq pt (polar 
                                      pt
                                      (setq disang (angle pt pt1))
                                      (* 2 (+ (distance pt pt1) (if (equal disang oldang 0.01) 0 h)))
                                    )
                          )
                        )
                        (list 70 (+ 128 (rem (MrAbu-dxf ent 70) 128)))
                      )
                    )
                  )
                  (progn 
                    (setq mov nil)
                    (MrAbu-chgent 
                      ent
                      (list (list 11 (polar pt (car item) disw)) (list 70 (+ 128 (rem (MrAbu-dxf ent 70) 128))))
                    )
                  )
                )
                )
                ((and 
                  (= (length l_adj) 2)
                  (setq item  (car l_adj)
                        item1 (cadr l_adj)
                  )
                  (or 
                    (and (> (setq disw (cadr item)) 0) (not (equal disw 0 1)) (> (caddr item) 0))
                    (and (> (setq disw (cadr item1)) 0) (not (equal disw 0 1)) (> (caddr item1) 0))
                  )
                )
                (if 
                  (or 
                    (> (MrAbu-dxf ent 70) 128)
                    (and 
                      (> (caddr item) 0)
                      (> (caddr item1) 0)
                      (> (setq disw (+ (cadr item) (cadr item1))) 0)
                      (not (equal disw 0 1))
                    )
                  )
                  (progn 
                    (setq pt1 (MrAbu-perpt pt (setq pt2 (MrAbu-dxf ent 10)) (polar pt2 ang 1200)))
                    (if (equal pt pt1 1) (setq disang (- ang (/ pi 2))) (setq disang (angle pt pt1)))
                    (MrAbu-chgent 
                      ent
                      (list 
                        (list 
                          11
                          (setq pt (polar pt disang (* 2 (+ (distance pt pt1) (if (equal disang oldang 0.01) 0 h)))))
                        )
                        (list 70 (+ 128 (rem (MrAbu-dxf ent 70) 128)))
                      )
                    )
                  )
                  (progn 
                    (setq mov nil)
                    (if (or (< (caddr item) 0) (< (setq disw (cadr item)) 0)) 
                      (setq item item1)
                    )
                    (MrAbu-chgent 
                      ent
                      (list (list 11 (polar pt (car item) (cadr item))) (list 70 (+ 128 (rem (MrAbu-dxf ent 70) 128))))
                    )
                  )
                )
                )
                (T (setq mov nil))
              )
            )
          )
          (vl-cmdf "_undo" "_e")
        )
      )
      (princ)
    )
)
(progn ;向量运算
    ;向量的长度-Vector Norm
    (defun MAT:norm (v) (sqrt (apply '+ (mapcar '* v v))))
    ;向量乘标量-Vector * Scalar
    (defun MAT:v*s (v s)(mapcar (function (lambda (x) (* x s))) v))
  
    ;两向量点积-Vector Dot Product
    (defun MAT:Dot (v1 v2) (apply '+ (mapcar '* v1 v2)))
    ;两向量叉积-Vector Cross Product
    (defun MAT:Cross (v1 v2)
        (list 
          (- (* (cadr v1) (caddr v2)) (* (caddr v1) (cadr v2))) ;AyBz-AzBy
          (- (* (caddr v1) (car v2)) (* (car v1) (caddr v2))) ;AzBx-AxBz
          (- (* (car v1) (cadr v2)) (* (cadr v1) (car v2))) ;AxBy-AyBx
        )
    )
  
    ;二维向量伪叉积-Vector Cross Product
    (defun MAT:Cross-2D (v1 v2)
      (- (* (car v1) (cadr v2)) (* (cadr v1) (car v2))) ;AxBy-AyBx
    )
  
    ;向量或点旋转(XOY平面, Ang为正时逆时针)
    (defun MAT:Rot2D (v ang / c s x y)
      ;(/ RealAng (/ 180 PI))；角度转弧度
      (setq c (cos ang) s (sin ang))
      (setq x (car v) y (cadr v))
      (list (- (* x c) (* y s)) (+ (* x s) (* y c)))
    )
  
    ;规格化向量(单位向量)-Unit Vector
    (defun MAT:UnitVec (v) 
      (
        (lambda (n) 
            (if (equal 0.0 n 1e-14) 
                nil
                (MAT:v*s v (/ 1.0 n))
            )
        ) 
        (sqrt (apply '+ (mapcar '* v v)));长度
      )
    )
    ;计算TgtPT到线StaPT-EndPT的垂足点坐标
    (defun MAT:PT2Line (TgtPT StaPT EndPT / Norms) 
        (setq Norms (mapcar '- EndPT StaPT);法向轴
              StaPT (trans StaPT 0 Norms)
              TgtPT (trans TgtPT 0 Norms)
        )
        (trans (list (car StaPT) (cadr StaPT) (caddr TgtPT)) Norms 0)
    )
    ;获取点表的排列方向:1顺时针，-1逆时针，0共线
    (defun MAT:ChkPtsCCW (pts / sum a b) 
      (setq sum (apply 
                  '+
                  (mapcar 
                      '(lambda (a b) (- (* (car b) (cadr a)) (* (car a) (cadr b))))
                      (cons (last pts) pts)
                      pts
                  )
                )
      )
      (cond 
        ((> sum 0) 1)
        ((< sum 0) -1)
        ((= sum 0) 0)
      )
    )
)

;定义视口
(defun C:DYSK (/ *error* CurDoc *Old_SysVar* pt0 TgtEn TgtSca Box1 TmpLst pt1 pt2 TmpEn  Fsten Box2 Lst1 Lst2 RVar FVar) 
  (setq CurDoc (vla-get-activedocument (vlax-get-acad-object)))
  (defun *error* (x)  ;出错函数
    (if TgtEn (vla-delete (vlax-ename->vla-object TgtEn)));删除矩形
    (if *Old_SysVar* (foreach xx *Old_SysVar* (apply 'setvar xx)));参数恢复
    (vla-endundomark CurDoc) ;错误时结束编组
  )

  (while (eq 8 (logand 8 (getvar 'undoctl))) 
    (vla-endundomark CurDoc)
  ) ;关闭以前的编组
  (vla-startundomark CurDoc) ;记录编组
    (progn ;记录系统变量
      (K:NLayNlock "PUB_WINDW" 250 :vlax-false);新建图层灰色不可打印

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
              (list "CLayer" "PUB_WINDW");切换图层
              (list "CMDECHO" 0) ;关闭回显
              (list "CECOLOR" "1") ;红色
            )
          )
      );记录参数
    )
    (setvar "TILEMODE" 1);进入模型空间

    (if (setq pt0 (getpoint))
        (progn
            (command "_.Rectang" pt0 PAUSE)
            (if 
                (and
                    (setq TgtEn (entlast))
                    (setq Box1 (K:GetUCSBox TgtEn))
                )
                (progn
                    (if TgtEn (vla-delete (vlax-ename->vla-object TgtEn)));删除矩形
                    (apply 'setvar (nth 2 *Old_SysVar*));恢复颜色
                    (setq TmpVar (if (DQ:HasTangent) (TGetPScale)(Getvar "DIMSCALE")));比例考虑天正    
                    (if (eq 1 (getvar "TILEMODE"))(setvar "TILEMODE" 0));进入布局空间
                    (if (> (getvar "CVPORT") 1) (command "_.pspace"));退出视口
                    (while ;get*
                      (progn 
                        (initget (+ 2 4) "X");非零非负值
                        (setq TgtSca 
                              (cond 
                                  ((getreal (strcat "\n→请输入标注比例[选图框(X)]1: <"(rtos TmpVar 2 1) ">")))
                                  (TmpVar)
                              )
                        )
                        (cond 
                          ((and (eq (type TgtSca) 'STR)(eq (strcase TgtSca) "X"));字母X
                              (while (not (setq Fsten (ssget ":S:E"))))
                              (if (setq Fsten (ssname Fsten 0))
                                  (progn
                                      (setq Box2 (K:GetUCSBox Fsten))
                                      (setq Lst1 (mapcar (function (lambda (a b) (abs (- a b)))) (car Box1) (cadr Box1))
                                            Lst2 (mapcar (function (lambda (a b) (abs (- a b)))) (car Box2) (cadr Box2))
                                      )
                                      (setq TgtSca (max (/ (car Lst1)  (car Lst2)) (/ (cadr Lst1)  (cadr Lst2))));较大的作为比例值
                                      (setq RVar
                                          (cond
                                              ((<= TgtSca 10) 2)
                                              ((< 10 TgtSca 20) 5)
                                              ((>= TgtSca 20) 10)
                                          )
                                      )
                                      (if (eq 0 (Setq FVar (fix (/ (+ TgtSca (* RVar 0.5)) RVar))))
                                          (setq TgtSca RVar)
                                          (setq TgtSca (* RVar FVar))
                                      );四舍五入
                                      (setq pt1 (car Box2))
                                  )
                              )
                              Nil ;退出循环
                          )
                          (T
                              (setvar "DIMSCALE" TgtSca);更新比例
                              (if (DQ:HasTangent) (TsetPScale TgtSca)) ;设置天正标注比例
                              (setq pt1 (getpoint "\n→请指定视口左下角：\n"))
                              Nil ;退出循环
                          )
                        )
                      )
                    )
                    (if 
                        (and
                          (setq TmpLst (mapcar (function (lambda (a b) (/ (abs (- a b)) TgtSca))) (car Box1) (cadr Box1)))
                          (setq pt2 (list (+ (car pt1) (car TmpLst)) (+ (cadr pt1) (cadr TmpLst)) 0.0))
                        )
                        (progn
                            (command "_.mview" "non" pt1 "non" pt2);创建视口
                            (if (setq TmpEn (entlast))
                                (progn
                                    (command "_.mspace");进入视口
                                    (command "_.plan" "");旋转对齐
                                    (command "_.zoom" "non" (car Box1) "non" (cadr Box1));缩放
                                    (command "_.pspace");退出视口
                                    (vlax-Put (vlax-ename->vla-object TmpEn) 'DisplayLocked :vlax-true);视口锁定
                                )
                            )
                        )
                    )
                )
            )
        )
    )
    (if *Old_SysVar* (foreach xx *Old_SysVar* (apply 'setvar xx)));参数恢复
  (vla-endundomark CurDoc) ;结束编组
  (princ)
)

;修改视口比例/标注比例(尺寸界限相应修改)@Kucha
(defun Sub:FixSca4Dim (PSpace enLst TgtSca / ScVar XX en ent obj
                    CenPT StaPT EndPT TgtDis DisSE AcrRad TgtPT TmpVar)
      (if enLst
          (progn
              (setq TgtLst (mapcar 
                            (function 
                              (lambda (XX) 
                                (list XX 
                                  (if PSpace
                                      (/ 1 (Vlax-Get (vlax-ename->vla-object XX) 'CustomScale))
                                      (Vlax-Get (vlax-ename->vla-object XX) 'ScaleFactor)
                                  )
                                )
                              )
                            )
                            enLst
                          )
              );处理信息成表
              (if (not TgtSca)
                  (if
                      (and
                          (setq ScVar (cadr (car TgtLst)));第一个标注
                          (or
                              (eq 1 (length TgtLst))
                              (equal
                                  ScVar
                                  (/ 
                                    (apply '+ (mapcar 'cadr (cdr TgtLst)))
                                    (length (cdr TgtLst))
                                  )
                                  1e-6
                              )
                          )
                      );比例是相等的
                      (progn
                        (initget (+ 2 4));非零非负值
                        (setq TgtSca 
                              (cond 
                                  ((getreal (strcat "\n→请输入标注比例1: <"(rtos ScVar 2 1) ">")))
                                  (ScVar)
                              )
                        )
                      )
                      (setq TgtSca (getreal (strcat "\n→请输入全局比例1: <*多种*>:")))
                  )
              );没有比例就提示输入
            
              (foreach XX TgtLst 
                  (setq en   (car XX)
                        ent  (entget en)
                        obj   (vlax-ename->vla-object en)    
                  )
                  (if PSpace
                      (progn
                          (setq CenPT (Vlax-Get obj 'Center))
                          (if (eq -1 (vlax-get obj 'Clipped));裁剪
                              (progn
                                  (vla-scaleentity (vlax-ename->vla-object (Cdr (Assoc 340 (Entget en)))) 
                                      (vlax-3d-point CenPT)
                                      (/ (caDr XX) TgtSca)
                                  )
                                  (vlax-put obj 'CustomScale (/ 1 TgtSca));设置比例
                              );已裁剪的视口
                              (progn
                                  (vla-scaleentity obj (vlax-3d-point CenPT)(/ (caDr XX) TgtSca))
                                  (vlax-put obj 'CustomScale (/ 1 TgtSca));设置比例
                              );未裁剪的视口
                          );缩放视口
                          (vlax-Put obj 'DisplayLocked :vlax-true);视口锁定
                          (vla-Update obj)
                      );处理视口
                      (progn
                          (vla-put-ScaleFactor obj TgtSca);设置比例
                          (cond
                              ((eq "ARC_DIMENSION" (K:GetDXF 0 ent));弧长标注
                                  (setq
                                        StaPT  (K:GetDXF 15 ent);圆心
                                        EndPT  (K:GetDXF 10 ent);定义点
                                        Uvec  (MAT:UnitVec (mapcar '- EndPT StaPT));单位向量

                                        DisSE  (distance StaPT EndPT)
                                        AcrRad (distance StaPT (K:GetDXF 13 ent))
                                        TgtDis (if (> DisSE AcrRad)
                                                    (+ AcrRad (* (/ TgtSca (cadr XX)) (- DisSE AcrRad)));圆弧外侧的情况
                                                    (progn
                                                        (setq TmpVar (- AcrRad (* (/ TgtSca (cadr XX)) (- AcrRad DisSE))));圆弧内侧的情况
                                                        (if (< TmpVar 1e-6)
                                                            DisSE
                                                            TmpVar
                                                        );避免特别小不显示的情况
                                                    ) 
                                              )
                                        ;缩放后的长度
                                  )
                                  (setq TgtPT (mapcar '+ StaPT (MAT:v*s Uvec TgtDis)))
                                  (entmod (subst (cons 10 TgtPT) (assoc 10 ent) ent));更新尺寸界限的位置   
                              )
                              ((member (K:GetDXF 70 ent) (list 1 33 161));对齐标注
                                  (setq
                                        StaPT (K:GetDXF 14 ent)
                                        EndPT (K:GetDXF 10 ent)
                                        Uvec  (MAT:UnitVec (mapcar '- EndPT StaPT));单位向量
                                        
                                        TgtDis (* (/ TgtSca (cadr XX)) (distance StaPT EndPT));缩放后的长度
                                  )
                                  (setq TgtPT (mapcar '+ StaPT (MAT:v*s Uvec TgtDis)))
                                  (entmod (subst (cons 10 TgtPT) (assoc 10 ent) ent));更新尺寸界限的位置
                              )
                              ((member (K:GetProp obj 'ObjectName) (list "AcDb2LineAngularDimension" "AcDb3PointAngularDimension"));角度标注
                                  (setq
                                        StaPT (K:GetDXF 15 ent)
                                        EndPT (K:GetDXF 10 ent)
                                        Uvec  (MAT:UnitVec (mapcar '- EndPT StaPT));单位向量
                                        
                                        TgtDis (* (/ TgtSca (cadr XX)) (distance StaPT EndPT));缩放后的长度
                                  )
                                  (setq TgtPT (mapcar '+ StaPT (MAT:v*s Uvec TgtDis)))
                                  (entmod (subst (cons 10 TgtPT) (assoc 10 ent) ent));更新尺寸界限的位置
                              )
                          );标注弧长
                      )
                  )
              )
          )
      )
      (princ)
      TgtSca
)
;改变(标注)比例
(defun C:GBBL (/ *error* CurDoc *Old_SysVar* PSpace SS TmpVar)
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
              (list "CMDECHO" 0) ;关闭回显
            )
          )
      );记录参数
    )
  
    (if (setq PSpace (and (eq (getvar "TILEMODE") 0)(eq (getvar "CVPORT") 1)));布局空间 
        (princ "\n——★★★ 请选择：布局视口 ★★★——\n")
        (princ "\n——★★★ 请选择：对齐标注+弧长标注 ★★★——\n")
    )
    (while (setq SS (ssget ":L" (list (if PSpace (cons 0 "VIEWPORT") (cons 0 "DIMENSION")))))
        (if (member (type (setq TmpVar (Sub:FixSca4Dim PSpace (K:SS->EntLst SS) Nil))) (list 'INT 'Real))
            (progn
                (setq Global:AllDimSca TmpVar)
                (setvar "DIMSCALE" Global:AllDimSca) ;CAD标注比例因子
                (if (DQ:HasTangent) (TsetPScale Global:AllDimSca)) ;设置天正标注比例
            )
        )
    )
    (if *Old_SysVar* (foreach xx *Old_SysVar* (apply 'setvar xx)));参数恢复
  
  (vla-endundomark CurDoc) ;结束编组
  (princ)
)

;尺寸(位置)自调
(defun C:CCZT (/ SS)
  (if (setq SS (ssget ":L" '((0 . "DIMENSION"))))
      (MrAbu:dimadjust SS)
  )
)
;尺寸文字复位
(defun C:WZFW (/ SS)
  (if (setq SS (ssget ":L" '((0 . "DIMENSION"))))
      (command ".dimedit" "_h" SS "")
  )
)

(defun C:DQ (/ CurDoc *Old_SysVar* *Old_TextLayer* DIMLay TmpDimSca isLayF 
                      SS SSP Tgten i en EnType Code en2 StaPT EndPT TmpLine IntLst pt PtLst TmpVar
                  )
    (setq CurDoc (vla-get-ActiveDOCument (vlax-get-acad-object)))
    (graphscr);返回图形交互界面
    (defun *error*(msg)
        (redraw)
        (if *Old_SysVar* (foreach xx *Old_SysVar* (apply 'setvar xx)));参数恢复
        (if isLayF (setq Global:DQ-DIMLay 1));恢复默认图层
        (vla-endundomark CurDoc)
    )
    (vla-startundomark CurDoc)
      (progn ;基础设置:图层及起始变量
          (setq DIMLay (list "PUB_DIM" (getvar "CLAYER")))
          (K:NLayNlock "PUB_DIM" 3 :vlax-true);新建图层绿色可打印
          (if (DQ:HasTangent)
              (progn
                  (if 
                      (or 
                        (> (TGetPScale) 1.0);大于零
                        (eq (getvar "CVPORT") 1.0);在布局中
                      ) ;当天正比例小于1时，取填充比例作为天正比例
                      (setq Global:AllDimSca (TGetPScale))
                      (setq Global:AllDimSca (getvar "HPSCALE"))
                  );标注比例
                  (TsetPScale Global:AllDimSca) ;设置天正标注比例
              )
              (setq Global:AllDimSca
                  (if (and (not Global:AllDimSca)  (equal (getvar "DIMSCALE") 1.0 1e-6))
                      (setvar "DIMSCALE" 50)
                      (getvar "DIMSCALE")
                  )
              );默认标注比例
          );默认获取天正比例

          (setq TmpDimSca
                 (if (and (eq (getvar "TILEMODE") 0)(eq (getvar "CVPORT") 1));布局空间
                      1 
                      Global:AllDimSca
                 )
          )
        
          (if (not Global:DQ-BoxTol) (setq Global:DQ-BoxTol 10)) ;分堆容差
          (if (not Global:DQ-ArcDis) (setq Global:DQ-ArcDis 5)) ;弧长标注与弧线距离的倍率
          (if (not Global:DQ-DIMLay) (setq Global:DQ-DIMLay 1)) ;1默认层,-1当前层
          (if (not Global:DQ-ArcMod) (setq Global:DQ-ArcMod 1)) ;1弧长半径,2仅标弧长,3仅标半径
        
          (if (not Global:DQ-FBlock) (setq Global:DQ-FBlock -1)) ;-1默认不栏选块
          (if (not Global:DQ-FHatch) (setq Global:DQ-FHatch -1)) ;-1默认不栏选填充
          ;---------
          (if (setq isLayF (eq 1 (logand 1 (cdr (assoc 70 (tblsearch "LAYER" (car DIMLay)))))));默认层冻结
              (progn
                (setq Global:DQ-DIMLay -1)
                (princ "\n——★★★ 默认层<PUB_DIM>已冻结, 标注将放在当前图层! ★★★——\n")
              )
          )
          (progn ;创建标注样式
              ;|
              (entmake 
                  (list 
                    (cons 0 "STYLE")
                    (cons 100 "AcDbSymbolTableRecord")
                    (cons 100 "AcDbTextStyleTableRecord")
                    (cons 2 "Standard")
                    (cons 70 0)
                    (cons 41 0.8)
                    (cons 3 "tssdeng.shx")
                    (cons 4 "hztxt.shx")
                  )
              );创建文字样式 Standard
              |;
              ;(if (not (tblsearch "BLOCK" "_ArchTick")) 
                (progn 
                  (entmake (list (cons 0 "BLOCK")(cons 70 0) (cons 10 '(0.0 0.0 0.0)) (cons 2 "_ArchTick")))
                    (entmake 
                      (list 
                        '(0 . "LWPOLYLINE")
                        '(100 . "AcDbEntity")
                        (cons 8 "0")
                        (cons 62 0)
                        (cons 6 "ByBlock")
                        '(100 . "AcDbPolyline")
                        '(90 . 2);顶点数
                        '(43 . 0.15);宽度
                        (cons 10 (list 0.5 0.5))
                        (cons 10 (list -0.5 -0.5))
                      )
                    );_ArchTick
                   ;|
                    (entmake 
                      (list 
                        '(0 . "LWPOLYLINE")
                        '(100 . "AcDbEntity")
                        (cons 8 "0")
                        (cons 62 0)
                        (cons 6 "ByBlock")
                        (cons 100 "AcDbPolyline")
                        (cons 90 2);顶点数
                        (cons 43 0.0);宽度
                        (cons 10 (list 0.5 0.5))
                        (cons 10 (list -0.5 -0.5))
                      )
                    );_Oblique
                    |;
                  (entmake (list '(0 . "ENDBLK")))
                )
              ;);生成空箭头块 _None
              (if (not (tblsearch "BLOCK" "_Closed")) 
                (progn 
                  (entmake (list (cons 0 "BLOCK")(cons 70 0) (cons 10 '(0.0 0.0 0.0)) (cons 2 "_Closed")))
                  (entmake 
                    (list 
                      '(0 . "LWPOLYLINE")
                      '(100 . "AcDbEntity")
                      (cons 8 "0")
                      (cons 62 0)
                      (cons 6 "ByBlock")
                      (cons 100 "AcDbPolyline")
                      (cons 90 3);顶点数
                      (cons 43 0.0);宽度
                      (cons 10 (list -0.5 0.5))
                      (cons 10 (list 0.0 0.0))
                      (cons 10 (list -0.5 -0.5))
                    )
                  );箭头
                  (entmake 
                    (list 
                      '(0 . "LWPOLYLINE")
                      '(100 . "AcDbEntity")
                      (cons 8 "0")
                      (cons 62 0)
                      (cons 6 "ByBlock")
                      (cons 100 "AcDbPolyline")
                      (cons 90 2);顶点数
                      (cons 43 0.0);宽度
                      (cons 10 (list 0.0 0.0))
                      (cons 10 (list -1.0 0.0))
                    );短线
                  )
                  (entmake (list '(0 . "ENDBLK")))
                )
              );生成箭头块 _Closed
              ;http://bbs.mjtd.com/forum.php?mod=viewthread&tid=191574&highlight=%B1%EA%D7%A2%D1%F9%CA%BD
              (entmake
                (list
                  (cons 0 "DIMSTYLE")
                  (cons 100 "AcDbSymbolTableRecord")
                  (cons 100 "AcDbDimStyleTableRecord")
                  (cons 342 (cdr (assoc 330 (entget (tblobjname "BLOCK" "_Closed")))))
                  (cons 2 "_DQ_Arrw");标注样式名称
                  (cons 70 0)    ;参照标记
                  (cons 41 1)    ;符号和箭头->箭头->箭头大小
                  (cons 42 3)    ;线->尺寸界线->起点偏移量：标注点到尺寸界线的距离
                  (cons 43 0)    ;线->尺寸线->基线间距
                  (cons 44 2)    ;线->尺寸界线->超出尺寸线
                  (cons 45 0)  ;舍入
                  (cons 73 0)    ;文字->文字对齐：水平=1，与尺寸线对齐=0，ISO标准=0
                  (cons 74 0)    ;文字->文字对齐：水平=1，与尺寸线对齐=0，ISO标准=1
                  (cons 77 1)    ;文字->文字位置->垂直：1=上，0=居中，4=下……
                  (cons 79 2)    ;文字->文字位置->垂直：1=上，0=居中，4=下……
                  (cons 90 1)    ;弧长符号在上方
                  (cons 140 3.0) ;文字->文字外观->文字高度
                  (cons 147 1)   ;文字->文字位置->从尺寸线偏移：填入负数时，“绘制文字边框”项会被勾选
                  (cons 172 1)   ;调整->优化：在尺寸界线之间绘制尺寸线，不勾选=0，勾选=1
                  (cons 174 1)   ;调整->调整选项：文字始终在尺寸界线之间=1，文字=0，箭头=0，文字和箭头=0，文字或箭头=0
                  (cons 175 0)   ;调整-调整选项-若箭头不能放在延伸线内则将其消除，不勾选=0，勾选=1
                  (cons 178 0) ;文字->文字外观->文字颜色，256=ByLayer，0=ByBlock，7=白色
                  (cons 179 1)   ;主单位->角度标注->精度：0=0，0.0=1，0.00=2
                  (cons 271 1)   ;主单位->线性标注->精度：0=0，0.0=1，0.00=2
                  (cons 272 0)   ;公差->公差格式->精度：0=0，0.0=1，0.00=2
                  (cons 279 0)   ;调整->文字位置：尺寸线上方不带引线=2，尺寸线上方带引线=1，尺寸线旁边=0
                  (cons 78  8)   ;主单位-线性标注-消零：后续，勾选=8
                  (cons 275 0)   ;主单位-角度标注-单位格式：十进制=0
                  (cons 79  2)   ;主单位-角度标注-消零：后续，勾选=2
                )
              );创建箭头标注样式 _DQ_Arrw
              (entmake
                (list
                  (cons 0 "DIMSTYLE")
                  (cons 100 "AcDbSymbolTableRecord")
                  (cons 100 "AcDbDimStyleTableRecord")
                  (cons 342 (cdr (assoc 330 (entget (tblobjname "BLOCK" "_ArchTick")))))
                  (cons 2 "_DQ_Arch");标注样式名称
                  (cons 70 0)    ;参照标记
                  (cons 41 1)    ;符号和箭头->箭头->箭头大小
                  (cons 42 3)    ;线->尺寸界线->起点偏移量：标注点到尺寸界线的距离
                  (cons 43 0)    ;线->尺寸线->基线间距
                  (cons 44 2)    ;线->尺寸界线->超出尺寸线
                  (cons 45 0)  ;舍入
                  (cons 73 0)    ;文字->文字对齐：水平=1，与尺寸线对齐=0，ISO标准=0
                  (cons 74 0)    ;文字->文字对齐：水平=1，与尺寸线对齐=0，ISO标准=1
                  (cons 77 1)    ;文字->文字位置->垂直：1=上，0=居中，4=下……
                  (cons 79 2)    ;文字->文字位置->垂直：1=上，0=居中，4=下……
                  (cons 90 1)    ;弧长符号在上方
                  (cons 140 3.0) ;文字->文字外观->文字高度
                  (cons 147 1)   ;文字->文字位置->从尺寸线偏移：填入负数时，“绘制文字边框”项会被勾选
                  (cons 172 1)   ;调整->优化：在尺寸界线之间绘制尺寸线，不勾选=0，勾选=1
                  (cons 174 1)   ;调整->调整选项：文字始终在尺寸界线之间=1，文字=0，箭头=0，文字和箭头=0，文字或箭头=0
                  (cons 175 0)   ;调整-调整选项-若箭头不能放在延伸线内则将其消除，不勾选=0，勾选=1
                  (cons 178 0)   ;文字->文字外观->文字颜色，256=ByLayer，0=ByBlock，7=白色
                  (cons 179 1)   ;主单位->角度标注->精度：0=0，0.0=1，0.00=2
                  (cons 271 1)   ;主单位->线性标注->精度：0=0，0.0=1，0.00=2
                  (cons 272 0)   ;公差->公差格式->精度：0=0，0.0=1，0.00=2
                  (cons 279 2)   ;调整->文字位置：尺寸线上方不带引线=2，尺寸线上方带引线=1，尺寸线旁边=0
                  (cons 78  8)   ;主单位-线性标注-消零：后续，勾选=8
                  (cons 275 0)   ;主单位-角度标注-单位格式：十进制=0
                  (cons 79  2)   ;主单位-角度标注-消零：后续，勾选=2
                )
              );创建线型标注样式 _DQ_Arch
          )
          (entmakex
            (list
              (cons 0 "LTYPE")
              (cons 100 "AcDbSymbolTableRecord")
              (cons 100 "AcDbLinetypeTableRecord")
              (cons 2 (strcat "DQ" (rtos (getvar "LTSCALE") 2 0)))
              (cons 70 0)
              (cons 3 "__ __ __")
              (cons 72 65)
              (cons 73 2)
              (cons 40 (/ 3.0 (getvar "LTSCALE")))
              (cons 49 (/ 2.0 (getvar "LTSCALE")))
              (cons 74 0)
              (cons 49 (/ -1.0 (getvar "LTSCALE")))
              (cons 74 0)
            )
          );根据当前比例制作虚线

      )
      ;--------
      (if (eq 4 (logand 4 (cdr (assoc 70 (tblsearch "LAYER" (if (eq 1 Global:DQ-DIMLay) (car DIMLay) (cadr DIMLay)))))))
        (alert (strcat "※程序出错：请解锁标注图层<" (if (eq 1 Global:DQ-DIMLay) (car DIMLay) (cadr DIMLay)) ">"))
        (progn
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
                    ;(list "DIMSCALE" TmpDimSca);标注比例因子
                    (list "CLAYER" (if (eq 1 Global:DQ-DIMLay) (car DIMLay) (cadr DIMLay)));图层名称
                    (list "peditaccept" 1);合并多段线时不提示
                    (list "expert" 5);禁止提示已存在
                    (list "cmdecho" 0) ;关闭回显
                  )
                )
            );记录参数
          )
          (if (not (null (last (ssgetfirst))));有预选对象
              (if (setq SS (ssget ":L"))
                  (if (setq SSP (ssget "P" '((0 . "DIMENSION"))));有标注
                      (if (= (sslength SSP) 1.0)
                          (progn
                              (setq Tgten (ssname SSP 0))
                              (cond
                                ((eq (Cdr (Assoc 0 (Entget Tgten))) "ARC_DIMENSION");弧长标注
                                    (princ "\n——★★★ 请选择点，进行连续标注 ★★★——\n")
                                    (K:DIM4EnLst T (list Tgten)) ;连续标注
                                )
                                ((and (eq (Cdr (Assoc 0 (Entget Tgten))) "DIMENSION") (member (Cdr (Assoc 70 (Entget Tgten))) (list 1 33 65 161)));对齐标注
                                    (princ "\n——★★★ 请选择点，进行连续标注 ★★★——\n")
                                    (K:DIM4EnLst nil (K:GetComDim Tgten)) ;连续标注
                                )
                                (T (princ "\n——★★★ 连续标注仅支持对齐标注和弧长标注 ★★★——\n"))
                              )
                          )
                          (progn
                              (princ "\n——★★★ 对齐标注和弧长标注，已尝试合并 ★★★——\n")
                              (K:MergeDim SSP)
                          )
                      )
                      (progn
                          (princ "\n——★★★ 将尝试标注：直线、多段线、圆、圆弧 ★★★——\n")
                          (repeat (setq i (sslength SS))
                              (setq en (ssname SS (setq i (1- i))))
                              (DQ:Dim4Ent en TmpDimSca Global:DQ-ArcMod Global:DQ-ArcDis)
                          )
                      )
                  )
              )
              (while 
                (progn 
                  (initget (+ 2 4) "S W B C R A") ;非零非负值
                  (setq StaPT 
                    (getpoint 
                      (strcat 
                        "\n→请输入栏选的第一点 或空格：["
                        "比例(S)_" (rtos TmpDimSca 2 2)
                        "/外框(W)/分堆(B)_" (rtos Global:DQ-BoxTol 2 0)
                        (if (eq Global:DQ-DIMLay 1) "/默认层(C)" "/当前层(C)")
                        (cond 
                          ((eq Global:DQ-ArcMod 1) "/弧长半径(R)")
                          ((eq Global:DQ-ArcMod 2) "/仅标弧长(R)")
                          ((eq Global:DQ-ArcMod 3) "/仅标半径(R)")
                        )
                        (if (/= Global:DQ-ArcMod 3) 
                          (strcat "/弧距(A)_" (rtos Global:DQ-ArcDis 2 0))
                          ""
                        )
                        "]"
                      )
                    )
                  )
                  (cond 
                    ((and (eq (type StaPT) 'STR)(eq (strcase StaPT) "W"));字母W
                      (while (setq SS (ssget ":L"))
                        (setq IntLst '());空表
                        (setq IntLst (apply 'K:RecLst4WCS (K:SSMinBoxLst Nil SS)))
                        (princ IntLst)
                        (if (eq (length IntLst) 2)
                            (DQ:DIM4PtLst IntLst TmpDimSca)
                            (progn
                                (DQ:DIM4PtLst (list (car IntLst) (cadr IntLst)) TmpDimSca)
                                (DQ:DIM4PtLst (list (cadr IntLst) (caddr IntLst)) TmpDimSca)
                                (entmakeX 
                                  (append 
                                    (list 
                                      '(0 . "LWPOLYLINE")
                                      '(100 . "AcDbEntity")
                                      '(100 . "AcDbPolyline")
                                      '(90 . 4);顶点4
                                      '(70 . 1);闭合多段线
                                      (cons 6 (strcat "DQ" (rtos (getvar "LTSCALE") 2 0)));线型
                                      (cons 48 TmpDimSca);线型比例
                                      (cons 8 (if (eq 1 Global:DQ-DIMLay) (car DIMLay) (cadr DIMLay)));图层
                                      (cons 62 251);颜色
                                    )
                                    (mapcar '(lambda (pt) (cons 10 pt)) IntLst)
                                  )
                                );画矩形
                            )
                        )
                      )
                      Nil ;退出循环
                    )
                    ((and (eq (type StaPT) 'STR)(eq (strcase StaPT) "B"));字母B
                      (progn
                        (initget (+ 2 4));非零非负值
                        (setq Global:DQ-BoxTol (cond 
                                    ((getreal (strcat "\n→请输入分堆容差：<" (rtos Global:DQ-BoxTol 2 0) ">")))
                                    (Global:DQ-BoxTol)
                                  )
                        )
                      )
                      (if Global:DQ-BoxTol
                          (progn
                              (princ (strcat "\n——★★★ 所选对象最大外框间距小于<" (rtos Global:DQ-BoxTol 2 0) ">时,被认为是同一堆! ★★★——\n"))
                              (if (setq SS (ssget ":L" ))
                                  (progn
                                      (setq IntLst '());空表
                                      (foreach XX (K:RtnBox4Group (K:SSAllBoxLst Nil SS) Global:DQ-BoxTol Global:DQ-BoxTol) 
                                          (setq IntLst (apply 'K:RecLst4WCS XX))
                                          (if (eq (length IntLst) 2)
                                              (DQ:DIM4PtLst IntLst TmpDimSca)
                                              (progn
                                                  (DQ:DIM4PtLst (list (car IntLst) (cadr IntLst)) TmpDimSca)
                                                  (DQ:DIM4PtLst (list (cadr IntLst) (caddr IntLst)) TmpDimSca)
                                                  (entmakeX 
                                                    (append 
                                                      (list 
                                                        '(0 . "LWPOLYLINE")
                                                        '(100 . "AcDbEntity")
                                                        '(100 . "AcDbPolyline")
                                                        '(90 . 4);顶点4
                                                        '(70 . 1);闭合多段线
                                                        (cons 6 (strcat "DQ" (rtos (getvar "LTSCALE") 2 0)));线型
                                                        (cons 48 TmpDimSca);线型比例
                                                        (cons 8 (if (eq 1 Global:DQ-DIMLay) (car DIMLay) (cadr DIMLay)));图层
                                                        (cons 62 251);颜色
                                                      )
                                                      (mapcar '(lambda (pt) (cons 10 pt)) IntLst)
                                                    )
                                                  );画矩形
                                              )
                                          )
                                      )
                                      (princ (strcat "\n——★★★ 分堆标注已完成，请检查! ★★★——\n"))
                                  )
                              )
                          )
                          (princ (strcat "\n——★★★ 间距值不存在,发生错误! ★★★——\n"))
                      )
                      Nil ;退出循环
                    )
                    ((and (eq (type StaPT) 'STR)(eq (strcase StaPT) "C"));字母C
                      (if isLayF
                          (princ "\n——★★★ 默认层<PUB_DIM>已冻结, 无法切换! ★★★——\n")
                          (if (eq 4 (logand 4 (cdr (assoc 70 (tblsearch "LAYER" (if (eq 1 Global:DQ-DIMLay) (cadr DIMLay)(car DIMLay)))))))
                              (princ (strcat "\n——★★★ 图层<" (if (eq 1 Global:DQ-DIMLay) (cadr DIMLay)(car DIMLay)) ">已锁定, 无法切换! ★★★——\n"))
                              (if (eq 1 (setq Global:DQ-DIMLay (* -1 Global:DQ-DIMLay))) ;1/-1
                                (setvar "CLAYER" (car DIMLay))
                                (setvar "CLAYER" (cadr DIMLay))
                              )
                          )
                      )
                      T ;继续循环
                    )
                    ((and (eq (type StaPT) 'STR)(eq (strcase StaPT) "R"));字母R
                      (cond
                        ((eq Global:DQ-ArcMod 1) (setq Global:DQ-ArcMod 2));弧长
                        ((eq Global:DQ-ArcMod 2) (setq Global:DQ-ArcMod 3));半径
                        ((eq Global:DQ-ArcMod 3) (setq Global:DQ-ArcMod 1));弧长半径
                      )
                      T ;继续循环
                    )
                    ((and (/= Global:DQ-ArcMod 3) (and (eq (type StaPT) 'STR)(eq (strcase StaPT) "A")));字母A
                      (progn
                        (initget (+ 2 4));非零非负值
                        (setq Global:DQ-ArcDis (cond 
                                  ((getint (strcat "\n→请输入弧长标注与弧线距离的倍率：<" (rtos Global:DQ-ArcDis 2 0) ">")))
                                  (Global:DQ-ArcDis)
                              )
                        )
                      )
                      (princ (strcat "\n——★★★ 弧长标注与弧线的距离将为当前标注比例X"(rtos Global:DQ-ArcDis 2 0)"倍! ★★★——\n"))
                      T ;继续循环
                    )
                    ((eq (type StaPT) 'LIST)
                      (while 
                        (progn 
                          (initget (+ 2 4) "B H") ;非零非负值
                          (setq EndPT 
                            (getpoint StaPT
                              (strcat 
                                "\n→请输入栏选的第一点：["
                                (if (eq Global:DQ-FBlock 1) "包含块(B)" "不含块(B)")
                                (if (eq Global:DQ-FHatch 1) "/包含填充(H)" "/不含填充(H)")
                                "]"
                              )
                            )   
                          )
                          (cond 
                            ((and (eq (type EndPT) 'STR)(eq (strcase EndPT) "B"));字母B
                              (setq Global:DQ-FBlock (* -1 Global:DQ-FBlock)) ;1/-1
                              T ;继续循环
                            )
                            ((and (eq (type EndPT) 'STR)(eq (strcase EndPT) "H"));字母H
                              (setq Global:DQ-FHatch (* -1 Global:DQ-FHatch)) ;1/-1
                              T ;继续循环
                            )
                            ((eq (type EndPT) 'LIST)
                              (if (setq SS (ssget "F" (list StaPT EndPT)));Ucs
                                  (progn
                                      (setq StaPT (trans StaPT 1 0) 
                                            EndPT (trans EndPT 1 0)
                                      );转WCS
                                      (setq IntLst '());空表
                                      (setq TmpLine (entmakeX (list (cons 0 "LINE")(cons 10 StaPT)(cons 11 EndPT))));创建临时直线
                                      (repeat (setq i (sslength SS)) 
                                          (setq en    (ssname SS (setq i (1- i)))
                                                EnType (cdr (assoc 0 (entget en)))
                                          )
                                          (cond 
                                            ((or 
                                              (member EnType '("LINE" "POLYLINE" "LWPOLYLINE" "ARC" "CIRCLE"))
                                              (and (eq Global:DQ-FHatch 1) (eq EnType "HATCH")) ;含填充
                                              )
                                              (setq IntLst (append (K:VxGetInters T TmpLine en 0) IntLst))
                                            );处理常规对象
                                            ((and
                                                (eq Global:DQ-FBlock 1)
                                                (eq EnType "INSERT") ;块
                                                (not (vlax-property-available-p (vlax-ename->vla-object en) 'Path)) ;没有路径=非外部参照
                                              )
                                              (setq IntLst (append (K:VxGetBLKinters T TmpLine en 0 Global:DQ-FHatch) IntLst))
                                            );处理块
                                          )
                                      );收集交点列表WCS
                                      (vla-delete (vlax-ename->vla-object TmpLine));删除临时直线
                                    
                                      (setq IntLst
                                          (vl-sort 
                                            (K:UniqueFuzz (append (K:WCSPt4Line SS StaPT EndPT) IntLst) 0.01);;合并点表后去重
                                            '(lambda (x y) (< (distance StaPT x) (distance StaPT y)))
                                          );排序:离起点越近越排在前面
                                      )
                                    
                                      (if (>= (length IntLst) 2) 
                                        (DQ:DIM4PtLst IntLst TmpDimSca)
                                        (progn
                                          (DQ:DIM4PtLst (list StaPT EndPT) TmpDimSca)
                                          (princ "\n——★★★ 没有交点或交点数量小于2, 将标注输入点! ★★★——\n")
                                        )
                                      )
                                  )
                                  (progn
                                    (DQ:DIM4PtLst (list (trans StaPT 1 0) (trans EndPT 1 0)) TmpDimSca)
                                    (princ "\n——★★★ 未栏选到任何对象, 将标注输入点! ★★★——\n")
                                  )
                              )
                              nil ;退出循环
                            );输入了起点，指定第二点
                            (T nil);空格结束，或可以改造成选择对象标注
                          )
                        )
                      )
                      nil ;退出循环
                    );输入了起点，指定第二点
                    ;(T nil);空格结束，或可以改造成选择对象标注
                    ((or
                        T
                        (and (eq (type StaPT) 'STR)(eq (strcase StaPT) "S"));字母S
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
                        (if (DQ:HasTangent) (TsetPScale Global:AllDimSca)) ;设置天正标注比例
                        T ;继续循环
                    )
                  )
                )
              )
          )
          (command "redraw")
          (foreach xx *Old_SysVar* (apply 'setvar xx));参数恢复
        )
      )
      (if isLayF (setq Global:DQ-DIMLay 1));恢复默认图层
    (vla-endundomark CurDoc)
    (princ)
)

(if (not (getenv "K\\ToolsIsExit"))
    (princ "\n——★★★ 快速标注由Kucha开发, 调用命令：DQ ★★★——\n") 
)(princ)