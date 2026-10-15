(if (null vlax-dump-object) (vl-load-com));将Visual LISP扩展功能加载到 AutoLISP

(defun C:RV (/ *Old_SysVar* CurDoc SS p1 p2 ANG VCTR VSZE ROP2 Tmp)
      (setq CurDoc (vla-get-ActiveDOCument (vlax-get-acad-object)))
      (defun *error* (msg) 
          (if *Old_SysVar* (foreach xx *Old_SysVar* (apply 'setvar xx)));参数恢复
          (vla-endundomark CurDoc)
      )
      (while (eq 8 (logand 8 (getvar 'undoctl))) 
        (vla-endundomark CurDoc)
      ) ;关闭以前的编组
      (vla-startundomark CurDoc)
        (progn ;记录系统变量
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
                  (list "VPROTATEASSOC" 1);视口内视图随视口旋转
                  ;(list "OSMode" 513);只捕捉最近点和端点
                  (list "cmdecho" 0) ;关闭回显
                )
              )
          );记录参数
        )
        (if (not (null (last (ssgetfirst))));有预选对象
            (if (and
                  (setq SS (ssget ":L"))
                  (setq p1 (getpoint "\n→请选择旋转中心: "))
                )
                (command "ROTATE" SS "" p1 "R" p1 pause pause)
            )
            (progn
              (setq VCTR (getvar "VIEWCTR");视图中心UCS
                    VSZE (getvar "VIEWSIZE");当前视图高度
              )
              (cond 
                ((eq (getvar "TILEMODE") 1);模型空间
                    ;(princ "\n——★★★ 在模型空间中 ★★★——\n")
                    (initget "R W")
                    (setq p1 (getpoint "\n→请选择旋转中心或 [恢复上次(R)/世界(W)]: "))
                    (cond
                      ((and (eq (type p1) 'STR)(eq (strcase p1) "R"))
                        (command "ucs" "P")
                        (princ "\n——★★★ UCS已回到上一个坐标系 ★★★——\n")
                      )
                      ((and (eq (type p1) 'STR)(eq (strcase p1) "W"))
                        (command "ucs" "W")
                        (princ "\n——★★★ UCS已回到世界坐标系 ★★★——\n")
                      )
                      ((and (eq (type p1) 'LIST)(setq p2 (getpoint p1 "\n→请选择X轴正方向: ")))
                          (setq ANG (Angle P1 p2))
                          (setq ROP2 (trans (polar VCTR (+ (angle VCTR p1) ANG) (distance VCTR p1)) 1 0));WCS
                          (initget (+ 2 4) "Y N")
                          (setq Tmp (cond 
                                          ((getkword (strcat "[Y-旋转视图/N-保持视图]：<N-保持视图>")))
                                          ("N")
                                        )
                          )
                          (if (equal "Y" Tmp) 
                            (progn 
                              (command "_UCS" "_Z" (Angtos ANG 0 15))
                              (command "_PLAN" "_C")
                              (while (> (getvar "CMDACTIVE") 0) (command PAUSE)) ;等待前面的命令完成
                              (command "_ZOOM" "_C" (trans ROP2 0 1) VSZE)
                              (command "_regen")
                              (princ "\n——★★★ UCS及视图已旋转 ★★★——\n")
                            )
                            (progn 
                              (command "_UCS" "_Z" (Angtos ANG 0 15))
                              (princ "\n——★★★ UCS已旋转,视图保持当前 ★★★——\n")
                            )
                          )
                      )
                      (t
                        (command "ucs" "W")
                        (princ "\n——★★★ UCS已回到世界坐标系 ★★★——\n")
                      )
                    )      
                )
                ((and (eq (getvar "TILEMODE") 0)(eq (getvar "CVPORT") 1));布局空间
                  ;(princ "\n——★★★ 在布局空间中 ★★★——\n")
                  (if 
                    (and
                      (princ "\n——★★★ 请选择需要旋转视图的视口 ★★★——\n")
                      (setq SS (ssget '((0 . "VIEWPORT"))))
                      (setq p1 (getpoint "\n→请选择旋转中心: "))
                      (setq p2 (getpoint p1 "\n→请选择X轴正方向: "))
                      (setq ANG (Angle P1 p2))
                    )
                    (progn
                      (command "_ROTATE" SS "" P1 (strcat "-" (Angtos ANG 0 15)));旋转视口
                      (while (> (getvar "CMDACTIVE") 0) (command PAUSE));等待前面的命令完成
                      (setvar "VPROTATEASSOC" 0);不旋转视口内对象
                      (command "_ROTATE" (ssget "P" ) "" P1 (Angtos ANG 0 15));反向旋转视口
                      (command "REGEN");刷新屏幕
                      (princ "\n——★★★ 视口内视图已旋转 ★★★——\n")
                    )
                  )
                )
                ((and (eq (getvar "TILEMODE") 0)(> (getvar "CVPORT") 1))
                    ;(princ "\n——★★★ 在活动视口中 ★★★——\n")
                    (initget "R W")
                    (setq p1 (getpoint "\n→请选择旋转中心或 [恢复上次(R)/世界(W)]: "))
                    (cond
                      ((and (eq (type p1) 'STR)(eq (strcase p1) "R"))
                        (command "ucs" "P")
                        (princ "\n——★★★ UCS已回到上一个坐标系 ★★★——\n")
                      )
                      ((and (eq (type p1) 'STR)(eq (strcase p1) "W"))
                        (command "ucs" "W")
                        (princ "\n——★★★ UCS已回到世界坐标系 ★★★——\n")
                      )
                      ((and (eq (type p1) 'LIST)(setq p2 (getpoint p1 "\n→请选择X轴正方向: ")))
                        (setq ANG (Angle P1 p2))
                        (command "_UCS" "_Z" (Angtos ANG 0 15))
                        (princ "\n——★★★ 视口内UCS已旋转 ★★★——\n")
                      )
                      (t
                        (command "ucs" "W")
                        (princ "\n——★★★ UCS已回到世界坐标系 ★★★——\n")
                      )
                    )
                )
              )
            )
        )
        (if *Old_SysVar* (foreach xx *Old_SysVar* (apply 'setvar xx)));参数恢复
      (vla-endundomark CurDoc)
      (princ)
)

(if (not (getenv "K\\ToolsIsExit"))
    (princ "\n——★★★ 旋转视图由Kucha开发，调用命令：RV ★★★——\n")
)(princ)
