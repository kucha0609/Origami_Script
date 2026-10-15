;---------------------------------=={解组中组 ← UG}==----------------------------------------;;
  (defun C:UNG (/ CurDoc SS i en Group) 
    (setq CurDoc (vla-get-activedocument (vlax-get-acad-Object)))
    (defun *error* (Msg)
      (vla-endundomark CurDoc)
    )
    (while (eq 8 (logand 8 (getvar 'undoctl))) 
        (vla-endundomark CurDoc)
    );关闭以前的编组
    (vla-startundomark CurDoc)
      (if (setq SS (ssget ":L" ))
          (repeat (setq i (sslength SS)) 
              (setq en (ssname SS (setq i (1- i))))
              (if (= "GROUP" (cdr (assoc 0 (entget (setq Group (cdr (assoc 330 (entget en))))))))
                  (entdel Group)
              );删除组
              (if (eq "HATCH" (Cdr (Assoc 0 (Entget en))))
                  (progn
                      (if (/= 0 (vlax-get (Vlax-Ename->Vla-Object en) 'AssociativeHatch))
                          (vlax-Put (Vlax-Ename->Vla-Object en) 'AssociativeHatch 0)
                      );解除关联
                      (Command "-HATCHEDIT" en "_H") ;创建独立的填充
                  )
              )
          )
      )
    (vla-endundomark CurDoc)
    (princ)
  )
;---------------------------------=={解组中组 ← UG}==----------------------------------------;;