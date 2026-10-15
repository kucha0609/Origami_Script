;全局变量Global:LineDeltaVal储存曲线伸长或缩短的增量
(defun C:DE ( / CurDoc OLD_CMD SS i en)  
  (setq CurDoc (vla-get-activedocument (vlax-get-acad-object)))
  (setq OLD_CMD (getvar "cmdecho"))
  (while (eq 8 (logand 8 (getvar 'undoctl))) 
      (vla-endundomark CurDoc)
  );关闭以前的编组
  (vla-startundomark CurDoc);记录编组
      (setvar "cmdecho" 0)
      (if (not Global:LineDeltaVal)(setq Global:LineDeltaVal 1000))
      (setq Global:LineDeltaVal
          (cond
              ((getreal (strcat "\n→请输入伸缩长度(正伸负缩): <"(rtos Global:LineDeltaVal)">")));输入值
              (Global:LineDeltaVal);回车使用之前的值
          )
      )
      (while (setq SS (ssget ":S" (list '(0 . "LINE,ARC,LWPOLYLINE"))));(cons 8 "D-12-Exist")
        (repeat (setq i (sslength ss))
          (setq en (ssname SS (setq i (1- i))))
          (command "_.LENGTHEN" "de" 
              Global:LineDeltaVal 
              (list en (trans (vlax-curve-getstartpoint (vlax-ename->vla-object en)) 0 1)) 
              (list en (trans (vlax-curve-getendpoint (vlax-ename->vla-object en)) 0 1)) 
              ""
          )
        )
      )
      (setvar "cmdecho" OLD_CMD)
  (vla-endundomark CurDoc);结束编组
  (princ)
)