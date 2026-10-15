;BurstUpgraded@LEEMAC 优化@Kucha
;修复了块内颜色和线型Byblock的问题
(defun C:Burst () (LM:burst Nil Nil))
(defun C:NBurst () (LM:burst T Nil))
;;----------------------------------------------------------------------;;

(progn ;基础函数
    (defun LM:burst (nst AllSS / *error* )
        (setq CurDoc (vla-get-activedocument (vlax-get-acad-object)))
        (defun *error* ( msg )
            (vla-endundomark CurDoc) ;错误时结束编组
            (princ)
        )
        (while (eq 8 (logand 8 (getvar 'undoctl))) 
          (vla-endundomark CurDoc)
        ) ;关闭以前的编组
        (vla-startundomark CurDoc) ;记录编组
          (if (setq SS
                  (ssget (if AllSS "A" "_:L")
                      (append '((0 . "INSERT"))
                          (
                              (lambda ( / def lst )
                                  (while (setq def (tblnext "block" (null def)))
                                      (if (= 4 (logand 4 (cdr (assoc 70 def))))
                                          (setq lst (vl-list* "," (cdr (assoc 2 def)) lst))
                                      )
                                  )
                                  (if lst (list '(-4 . "<NOT") (cons 2 (apply 'strcat (cdr lst))) '(-4 . "NOT>")))
                              )
                          )
                          (if (= 1 (getvar 'cvport))
                              (list (cons 410 (getvar 'ctab)))
                            '((410 . "Model"))
                          )
                      )
                  )
              )
              (repeat (setq i (sslength SS)) 
                (LM:burstobject 
                    (vlax-ename->vla-object (ssname SS (setq i (1- i))))
                    nst
                )
              )
          )
        (vla-endundomark CurDoc) ;结束编组
        (princ)
    )

    (defun LM:burstobject ( obj nst / LM:usblock-p LM:entlast cmd col LayCol ent err lay lin lst qaf tmp )
        ;是均匀缩放块@Lee Mac
        (defun LM:usblock-p ( obj / s )
            (if (vlax-property-available-p obj 'xeffectivescalefactor)
                (setq s "effectivescalefactor")
                (setq s "scalefactor")
            )
            (and
                (equal
                  (abs (vlax-get-property obj (strcat "x" s)))
                  (abs (vlax-get-property obj (strcat "y" s)))
                  1e-8
                )
                (equal
                  (abs (vlax-get-property obj (strcat "x" s)))
                  (abs (vlax-get-property obj (strcat "z" s)))
                  1e-8
                )
            )
        )
        ;返回数据库中最后一个子实体的包装器@Leemac
        (defun LM:entlast ( / en tmp )
            (setq en (entlast))
            (while (setq tmp (entnext en)) (setq en tmp))
            en
        )
        (if
            (and
                (= "AcDbBlockReference" (vla-get-objectname obj))
                (not (vlax-property-available-p obj 'path))
                (vlax-write-enabled-p  obj)
                (or (and (LM:usblock-p obj)
                        (not (vl-catch-all-error-p (setq err (vl-catch-all-apply 'vlax-invoke (list obj 'explode)))))
                        (setq lst err)
                    )
                    (progn
                        (setq tmp (vla-copy obj)
                              ent (LM:entlast)
                              cmd (getvar 'cmdecho)
                              qaf (getvar 'qaflags)
                        )
                        (setvar 'cmdecho 0)
                        (setvar 'qaflags 0)
                        (vl-cmdf "_.explode" (vlax-vla-object->ename tmp));分解
                        (setvar 'qaflags qaf)
                        (setvar 'cmdecho cmd)
                        (while (setq ent (entnext ent))
                            (setq lst (cons (vlax-ename->vla-object ent) lst))
                        );收集分解的块的内容?
                        lst
                    )
                )
            );分解块
            (progn
                (setq lay (vla-get-layer    obj)
                      col (vla-get-color    obj)
                      Laycol (vla-get-color (vlax-ename->vla-object (tblobjname "layer" lay)))
                      lin (vla-get-linetype obj)
                )
                (foreach XX (vlax-invoke obj 'getattributes)
                    (if (vlax-write-enabled-p XX)
                        (progn
                            (if (= acbyblock (vla-get-color XX))
                                (if (= acBYLAYER col)
                                  (vla-put-color XX LayCol)
                                  (vla-put-color XX col)
                                )
                            )
                            (if (= "byblock" (strcase (vla-get-linetype XX) t))
                                (vla-put-linetype XX lin)
                            )
                            (if (= "0" (vla-get-layer XX))
                                (vla-put-layer XX lay)
                            )
                        )
                    )
                    (if
                        (and
                            (= :vlax-false (vla-get-invisible XX))
                            (= :vlax-true  (vla-get-visible   XX))
                        )
                        (   (if (and (vlax-property-available-p XX 'mtextattribute) (= :vlax-true (vla-get-mtextattribute XX)))
                                Burst:matt2mtext 
                                Burst:att2text
                            )
                            (entget (vlax-vla-object->ename XX))
                        )
                    )
                );属性文字
                (foreach XX lst
                    (cond
                        ((not (vlax-write-enabled-p XX)))
                        ((= :vlax-false (vla-get-visible XX))
                            (vla-delete XX)
                        )
                        (t
                            (if (= acbyblock (vla-get-color XX))
                                (if (= acBYLAYER col)
                                  (vla-put-color XX LayCol)
                                  (vla-put-color XX col)
                                )
                            )
                            (if (= "byblock" (strcase (vla-get-linetype XX) t))
                                (vla-put-linetype XX lin)
                            )
                            (if (= "0" (vla-get-layer XX))
                                (vla-put-layer XX lay)
                            );图层
                            (if (= "AcDbAttributeDefinition" (vla-get-objectname XX))
                                (progn
                                    (if
                                        (and
                                            (= :vlax-true  (vla-get-constant  XX))
                                            (= :vlax-false (vla-get-invisible XX))
                                        )
                                        (   (if (and (vlax-property-available-p XX 'mtextattribute) (= :vlax-true (vla-get-mtextattribute XX)))
                                                Burst:matt2mtext 
                                                Burst:att2text
                                            )
                                            (entget (vlax-vla-object->ename XX))
                                        )
                                    )
                                    (vla-delete XX)
                                )
                                (if nst (LM:burstobject XX nst))
                            )
                        )
                    )
                );分解的块
                (vla-delete obj)
            )
        )
    )

    (defun Burst:removepairs ( itm lst )
        (vl-remove-if '(lambda ( x ) (member (car x) itm)) lst)
    )

    (defun Burst:remove1stpairs ( itm lst )
        (vl-remove-if '(lambda ( x ) (if (member (car x) itm) (progn (setq itm (vl-remove (car x) itm)) t))) lst)
    )
      
    (defun Burst:att2text ( enx )
        (entmakex
            (append '((0 . "TEXT"))
                (Burst:removepairs '(000 002 003 070 074 100 280 440)
                    (subst (cons 73 (cdr (assoc 74 enx))) (assoc 74 enx) enx)
                )
            )
        )
    )

    (defun Burst:matt2mtext ( enx )
        (entmakex
            (append '((0 . "MTEXT") (100 . "AcDbEntity") (100 . "AcDbMText"))
                (Burst:remove1stpairs
                    (if (= "ATTDEF" (cdr (assoc 0 enx)))
                      '(001 003 007 010 040 041 050 071 072 073 210)
                      '(001 007 010 040 041 050 071 072 073 210)
                    )
                    (Burst:removepairs '(000 002 011 042 043 051 070 074 100 101 102 280 330 360 440) enx)
                )
                (list (assoc 011 (reverse enx)))
            )
        )
    )
)
