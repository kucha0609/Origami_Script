;显隐视口比例由Kucha开发@Kucha007

(if (null vlax-dump-object) (vl-load-com));将Visual LISP扩展功能加载到 AutoLISP


(defun C:SV (/ CurDOC *Old_SysVar* SSTE SSVP)
      (setq CurDOC (vla-get-ActiveDOCument (vlax-get-acad-object)))
      (defun *error*(msg)
        (if *Old_SysVar* (foreach xx *Old_SysVar* (apply 'setvar xx)));参数恢复
        (vla-endundomark CurDOC)
      )
      (progn ;基础函数
        ;新建图层：图层名称、图层颜色、是否打印、全解(:vlax-false不打印，:vlax-true打印)
        (defun K:NewLay (LayNam Col Plt Flag / TgtEn TgtObj) 
          ;若图层不存在则新建。若存在则检查图层更新颜色和打印状态。Flag为T时解锁、解冻、打开
          (if (setq TgtEn (tblobjname "layer" LayNam)) 
              (progn  ;更新参数
                  (setq TgtObj (vlax-ename->vla-object TgtEn))
                  (vla-put-color TgtObj Col) ;更新颜色
                  (vla-put-Plottable TgtObj Plt) ;更新可打印状态
                  (if Flag
                    (progn
                        (vla-put-lock  TgtObj :vlax-false);解锁
                        (if (/= LayNam (getvar "Clayer"))
                            (vla-put-Freeze  TgtObj :vlax-false);解冻
                        );不等于当前图层则解冻
                        (vla-put-layeron  TgtObj :vlax-true);打开
                    )
                  )
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
        ;移动非视口层的视口到视口图层VPLay@Kucha
        (defun K:MoveVP2Lay (VPLay Col / ObjLst SSVP i en ent obj) 
            (K:NewLay VPLay Col :vlax-false Nil);新建视口图层
            (setq ObjLst Nil);清空变量避免串门
            (setq SSVP 
                (ssget "X" 
                  (list 
                    (cons -4 "<AND")
                      (cons -4 "<OR")
                        ;(cons -4 "<AND")
                          (cons -4 "<OR")
                            (cons 0 "LWPOLYLINE") ;多段线
                            (cons 0 "ELLIPSE") ;椭圆
                            (cons 0 "CIRCLE") ;圆
                          (cons -4 "OR>")
                          ;(cons 102 "{ACAD_REACTORS");视口裁剪
                        ;(cons -4 "AND>")
                        (cons -4 "<AND")
                          (cons 0 "VIEWPORT")
                          (cons -4 "<NOT")
                            (cons 69 1);忽略当前视口 
                          (cons -4 "NOT>")
                        (cons -4 "AND>")
                      (cons -4 "OR>")
                      (cons 8 (strcat "~" VPLay))
                      (cons 410 (getvar "ctab"));当前布局
                    (cons -4 "AND>")
                  )
                )
            );选择非视口图层的视口(含裁剪)
            (if SSVP 
                (repeat (setq i (sslength SSVP)) 
                  (setq en (ssname SSVP (setq i (1- i)))
                        ent (entget en)
                  )
                  (if 
                      (and
                        (/= 4 (logand 4 (cdr (assoc 70 (tblsearch "LAYER" (Cdr (Assoc 8 (Entget en))))))));非锁图层
                        (or
                            (eq "VIEWPORT" (Cdr (Assoc 0 (Entget en))));是视口
                            (and  
                              (setq ent (member (cons 102 "{ACAD_REACTORS") ent))
                              (setq ent (member (cons 102 "}") (reverse ent)))
                              (eq "VIEWPORT" (Cdr (Assoc 0 (Entget (cdr (assoc 330 ent))))))
                            );是裁剪视口
                        )
                      )
                      (progn
                          (setq ObjLst (cons (setq obj (vlax-ename->vla-object en)) ObjLst));收集对象
                          (vla-put-layer obj "PUB_WINDW")
                          (vla-put-color obj 256);随层色
                          (vla-Update obj)
                      )
                  )
                )
            )
            (if ObjLst (princ (strcat "\n——★★★ 非视口层的视口已移动到不可打印层<" VPLay "> ★★★——")))
            (princ)
        );(K:MoveVP2Lay "PUB_WINDW" 250)
        ;在右下角标注选择集中每一个视口的比例
        (defun K:MkSSVPText (TgtSS TELay / K:GetVPScSTR i en SCSTR MinPT MaxPT TgtPT)
          ;获取视口比例对应的字符串
          (defun K:GetVPScSTR (en / Err STR TxH SCV)
            (setq Err Nil ;判断比例是否大于1
                  STR   Nil ;清空文字内容避免串门
                  TxH   20.0 ;文字高度默认20  
                  SCV   (vla-get-CustomScale (Vlax-Ename->Vla-Object en))
            )
            (cond
              ((and SCV (>= SCV 1.0));大于等于1，例如1:1或5：1
                (setq STR (strcat (rtos SCV 2 0) ":1" ));取整数部分
                (if (/= (distof (rtos SCV 2 2))(distof (rtos SCV 2 0)))(setq Err T));非整数且尾数大于0.01
              )
              ((and SCV (< SCV 1.0));小于1，例如1:20
                (setq STR (strcat "1:" (rtos (setq SCV (/ 1.0 SCV)) 2 0)));取整数部分
                (if (< SCV 100);小于100
                    (setq TxH 10.0);文字高度改为10
                )
                (if (/= (distof (rtos SCV 2 2))(distof (rtos SCV 2 0)))(setq Err T));非整数且尾数大于0.01
              )
              (T (setq STR "未知的错误" )(setq Err T))
            )
            (list Err TxH STR)
          )
          (repeat (setq i (sslength TgtSS))
            (setq en (ssname TgtSS (setq i (1- i))))
            (if (eq "VIEWPORT" (Cdr(Assoc 0 (Entget en))))
              (progn
                (vla-GetBoundingBox (vlax-ename->vla-object en) 'MinPT 'MaxPT);取最小边界框
                (setq MinPT (vlax-safearray->list MinPT)
                      MaxPT (vlax-safearray->list MaxPT)
                )
                (setq TgtPT (list (- (car MaxPT) 5) (+ (cadr MinPT) 5) 0.0));计算插入点在右下角
                (setq SCSTR (K:GetVPScSTR en));获取视口信息
                (entmake
                  (list
                    (cons 0 "TEXT")
                    (cons 8 TELay);图层名称
                    (cons 62  (if (car SCSTR) 1 2));文字颜色,错误是红,正确是黄
                    (cons 10 TgtPT);第一对齐点
                    (cons 40 (cadr SCSTR)) ;文字高度
                    (cons 1 (Last SCSTR));文字内容
                    (cons 72 2);对齐方式:0=左对正；1=居中对正；2=右对正；3=对齐；4=正中
                    (cons 11 TgtPT);第二对齐点
                  )
                )
              )
            )
          )
        )
      )
      (while (eq 8 (logand 8 (getvar 'undoctl))) 
        (vla-endundomark CurDoc)
      ) ;关闭以前的编组
      
      (vla-startundomark CurDOC) ;记录编组
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
                  (list "cmdecho" 0) ;关闭回显
                )
              )
          );记录参数 
          (K:NewLay "K-视口比例" 2 :vlax-false T);新建文字图层
        )
        (if (and (eq (getvar "TILEMODE") 0)(eq (getvar "CVPORT") 1));在布局空间
          (progn
              (K:MoveVP2Lay "PUB_WINDW" 250);移动非视口层的对象到视口层
              (if (setq SSTE (ssget "X" (list(cons 8 "K-视口比例")(cons 410 (getvar "ctab"))))) ;当前布局视口文字存在
                (progn
                    (command "_.Erase" SSTE "")
                    (princ "\n——★★★ 当前布局的视口比例标注已删除! ★★★——")
                );删除所有文字标注
                (if 
                    (setq SSVP (ssget "X" (list 
                                            (cons 0 "VIEWPORT")(cons 410 (getvar "ctab"));当前布局
                                            (cons -4 "<NOT")(cons 69 1)(cons -4 "NOT>");忽略当前视口 
                                          )
                            )
                    );全选当前布局的视口
                    (progn
                      (K:MkSSVPText SSVP "K-视口比例");标注视口比例
                      (princ "\n——★★★ 当前布局的视口比例已全部标注! ★★★——")
                    )
                    (princ "\n——★★★ 当前布局不存在视口! ★★★——")
                );文字标注所有视口
              )
          )
          (princ "\n——★★★ 此命令仅可在布局中使用! ★★★——")
        )
        (command "redraw")
        (if *Old_SysVar* (foreach xx *Old_SysVar* (apply 'setvar xx)));参数恢复
      (vla-endundomark CurDOC) ;结束编组 
      (princ)
)


(if (not (getenv "K\\ToolsIsExit")) 
  (princ "\n——★★★ 显隐视口比例由Kucha开发，调用命令: SV ★★★——") 
)(princ)