(defun C:BG (/ *error* CurDoc BGCol) 
    (setq CurDoc (vla-get-activedocument (vlax-get-acad-object)))
    (defun *error* (x)  ;出错函数
      (vla-endundomark CurDoc) ;错误时结束编组
    )
    (while (eq 8 (logand 8 (getvar 'undoctl))) 
      (vla-endundomark CurDoc)
    ) ;关闭以前的编组
    (vla-startundomark CurDoc) ;记录编组
      ;背景色值参考: 黑色=0，254号浅灰=14079702，252号深灰=8684676，白色=16777215
      (setq BGCol (if (/= "0" (getenv "Background")) "0" "16777215"))
      (vl-catch-all-apply 
        '(lambda (/ *DisP) 
            (setq *DisP (vlax-get-property (vlax-get-property (vlax-get-acad-object) 'Preferences) 'Display))
            (vlax-put-property *DisP 'GraphicsWinModelBackgrndColor BGCol) ;设置模型背景色
            (vlax-put-property *DisP 'GraphicsWinLayoutBackgrndColor BGCol) ;设置布局背景色
            (setenv "BEditBackground" BGCol);设置块编辑器背景色
            (setenv "Background" BGCol);重新设置模型背景色(避免失效)
            (if (eq "0" BGCol)
                (princ "\n——★★★ 背景色已切换为黑色 ★★★——\n")
                (princ "\n——★★★ 背景色已切换为白色 ★★★——\n")
            )
          )
      )
      (command "redraw");清空一行
    (vla-endundomark CurDoc) ;结束编组
    (princ)
)
