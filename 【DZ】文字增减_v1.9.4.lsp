;http://bbs.mjtd.com/forum.php?mod=viewthread&tid=180794&fromuid=7329538

;单字递增 by 1028695446
;优化 by Kucha2023
(vl-load-com)
(defun C:DZ (/ *error* Doc *Old_SysVar* OneSTRLst MoreSTRLst MatchSTRLst Code TgtPT OriEnLst OriEn TgtObj ObjNam HasTgtObj TgtSTR NewSTR) 
  (setq Doc (vla-get-activedocument (vlax-get-acad-object)))
  (defun *error* (msg) 
    (if *Old_SysVar* (foreach xx *Old_SysVar* (apply 'setvar xx))) ;参数恢复
    (vla-endundomark Doc) ;结束编组 
  )
  (progn ;基础函数
    ;收集选择集中的实体成表 by Lee Mac
    (defun K:SS->EntLst (SS / i EntLst) 
      (if SS 
        (repeat (setq i (sslength SS)) 
          (setq EntLst (cons (ssname SS (setq i (1- i))) EntLst))
        )
      )
    )
    ;返回列表中特定字符串的索引
    (defun K:FindStrPos (Str Lst)
      (vl-position (strcase Str) (mapcar 'strcase Lst))
    )
    ;实体的字符串拆分成单字,并且返回单字的选择集
    (defun K:BreakAllText (MatchSTRLst en TgtSTR / K:ExplodeSTR LayNam SS ent Ang IPT ExpSTR EntLst STR Width TextEnt)
      (progn ;基础函数
        ;将字符串拆分成单字符列表
        (defun K:ExplodeSTR (MatchSTRLst STR / Defined xx STRDefined RtnSTR Pos)
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
          (foreach xx MoreSTRLst
            (setq Defined (append Defined xx))
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
        ;根据NewLst子表中的首元素 替换或追加OriLst中对应表元
        (defun K:Update-AssocLst (NewLst OriLst Additem / K Olditem) 
          (foreach K NewLst 
            (if (setq Olditem (assoc (car K) OriLst)) 
              (setq OriLst (subst K Olditem OriLst))
              (if Additem (setq OriLst (append OriLst (list K))))
            )
          )
          OriLst
        )
        ;获取字符串的宽度(包含空格)
        (defun K:GetSTRWidth (STR EntData / TBox1 TBox2) 
          ;"mm"是为了测量空格的长度
          (if (not STR) (setq STR (cdr (assoc 1 EntData))))
          (setq TBox1 (Textbox (K:Update-AssocLst (list (cons 1 (strcat "m" STR "m"))) EntData T)))
          (setq TBox2 (Textbox (K:Update-AssocLst (list (cons 1 "mm")) EntData T)))
          (- 
            (- (caadr TBox1) (caar TBox1))
            (- (caadr TBox2) (caar TBox2))
          )
        )
      )
      (setq LayNam (cdr (assoc 8 (entget en))))
      (if (eq 4 (logand 4 (cdr (assoc 70 (tblsearch "LAYER" LayNam)))))
        (progn 
          (alert (strcat "※无法运行程序！\n\n文字图层<" LayNam ">已锁定"))
          (exit);强制退出
        )
        (progn
          (redraw en 2) ;隐藏实体
          (setq SS  (ssadd)
                ent (entget en)
                Ang (cdr (assoc 50 ent))
                IPT  (cdr (assoc 10 ent))
          )
          (setq ExpSTR (K:ExplodeSTR MatchSTRLst TgtSTR)) ;将字符串拆解成单字列表
          (setq EntLst 
              (list 
              '(0 . "TEXT")
              (assoc 8 ent) ;图层
              (assoc 40 ent) ;高度
              (assoc 41 ent) ;宽度
              (assoc 7 ent) ;样式
              (assoc 71 ent) ;文字镜像
              (cons 50 Ang) ;转角
              (assoc 51 ent) ;倾角
            )
          )
          (while ExpSTR
            (setq STR (car ExpSTR))
            (setq Width (K:GetSTRWidth STR EntLst))
            (setq TextEnt (entmakeX  (K:Update-AssocLst (list (cons 1 STR) (cons 10 IPT)) EntLst T)));创建文字
            (setq SS (ssadd TextEnt SS))
            (if (eq (boole 1 (cdr (assoc 71 EntLst)) 2) 2)
              (setq IPT (polar IPT Ang (- 0 Width)))
              (setq IPT (polar IPT Ang Width))
            )
            (setq ExpSTR (cdr ExpSTR))
          )
          (redraw en 1) ;显示实体
        )
      )
      SS ;生成的全部单字
    )
    ;返回分解并且处理后合并的字符串
    ;MatchSTRLst为特定字符列表,Flag为T时正向匹配
    (defun K:STR-AfterChange (En PT TgtSTR MatchSTRLst Flag / TmpSS TmpEn STR StrAscii AftSTR NewSTR i)
      (setq TmpSS (K:BreakAllText MoreSTRLst En TgtSTR))
      (command "_DrawOrder" TmpSS "" "F");生成的单字置顶
      (if 
        (setq TmpEn (car (nentselp PT))
              STR (cdr (assoc 1 (entget TmpEn)))
              StrAscii (ascii STR)
              AftSTR
              (cond 
                ((< 47 StrAscii 58) ;0~9
                  (if Flag
                    (if (eq StrAscii 57)
                        (chr 48)
                        (chr (1+ StrAscii))
                    )
                    (if (eq StrAscii 48)
                        (chr 57)
                        (chr (1- StrAscii))
                    )
                  )
                )
                ((< 64 StrAscii 91) ;A~Z
                  (if Flag
                    (if (eq StrAscii 90)
                        (chr 65)
                        (chr (1+ StrAscii))
                    )
                    (if (eq StrAscii 65)
                      (chr 90)
                      (chr (1- StrAscii))
                    )
                  )
                )
                ((< 96 StrAscii 123) ;a~z
                  (if Flag
                    (if (eq StrAscii 122)
                        (chr 97)
                        (chr (1+ StrAscii))
                    )
                    (if (eq StrAscii 97)
                        (chr 122)
                        (chr (1- StrAscii))
                    )
                  )
                )
                (
                  (setq MatchSTR 
                    (vl-some 
                      '(lambda (Lst) 
                        (if (setq Pos (K:FindStrPos STR Lst)) 
                          (if Flag
                              (if (eq (1+ Pos)(length Lst)) 
                                (car Lst)
                                (nth (1+ Pos) Lst)
                              )
                              (if (eq Pos 0) 
                                (Last Lst)
                                (nth (1- Pos) Lst)
                              )
                          )

                        )
                      )
                      MatchSTRLst
                    )
                  )
                  MatchSTR
                )
              )   
        )
        (progn ;更新文字内容
          (entmod (subst (cons 1 AftSTR) (assoc 1 (entget TmpEn)) (entget TmpEn))) ;更新实体数据库
          (setq NewSTR
            (apply 'strcat
              (mapcar 
                '(lambda (XX) (cdr (Assoc 1 (Entget XX))))
                (K:SS->EntLst TmpSS)
              )
            )
          );新的字符串
        )
      )
      (repeat (setq i (sslength TmpSS))
        (entdel (ssname TmpSS (setq i (1- i))))
      );删除单字
      NewSTR
    )
  )
  (vla-startundomark Doc) ;记录编组
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
              (list "SHORTCUTMENU" 11) ;使快捷菜单可用
              (list "OSMode" 0) ;取消捕捉
              (list "cmdecho" 0) ;关闭回显
            )
          )
      );记录参数
      ;单字符列表:相同的字符不能重复出现,否则容易匹配错误
      (setq OneSTRLst 
        (list 
          '("零" "壹" "贰" "叁" "肆" "伍" "陆" "柒" "捌" "玖" "拾" "佰" "仟" "萬" "億")
          '("一" "二" "三" "四" "五" "六" "七" "八" "九" "十")
          '("甲" "乙" "丙" "丁" "戊" "己" "庚" "辛" "壬" "癸")
          '("㈠" "㈡" "㈢" "㈣" "㈤" "㈥" "㈦" "㈧" "㈨" "㈩") ;括号汉字
          '("⑴" "⑵" "⑶" "⑷" "⑸" "⑹" "⑺" "⑻" "⑼" "⑽") ;括号数字
          '("①" "②" "③" "④" "⑤" "⑥" "⑦" "⑧" "⑨" "⑩") ;圆圈数字
          '("Ⅰ" "Ⅱ" "Ⅲ" "Ⅳ" "Ⅴ" "Ⅵ" "Ⅶ" "Ⅷ" "Ⅸ" "Ⅹ" "Ⅺ" "Ⅻ") ;罗马数字1-12大写
          '("ⅰ" "ⅱ" "ⅲ" "ⅳ" "ⅴ" "ⅵ" "ⅶ" "ⅷ" "ⅸ" "ⅹ") ;罗马数字1-10小写
          '("红" "橙" "黄" "绿" "青" "蓝" "紫")
          '("前" "后" "左" "右" "上" "下")
          '("东" "西" "南" "北" "中")
          '("酸" "甜" "苦" "辣" "咸")

          '("春" "夏" "秋" "冬")
          '("加" "减" "乘" "除")
          '("江" "河" "湖" "海")

          '("天" "地" "人")
          '("年" "月" "日")
          '("时" "分" "秒")
          '("黑" "白" "灰")
          '("平" "立" "剖")
          '("正" "背" "侧")

          '("大" "小")
          '("多" "少")
          '("主" "次")
          '("给" "排")
          '("梁" "板")
          '("水" "电")
          '("雨" "污")
          '("男" "女")
          '("开" "关")
          '("进" "出")
          '("新" "旧")
          '("美" "丑")
          '("好" "坏")
          '("动" "静")
          '("冷" "热")
          '("强" "弱")
          '("明" "暗")
          '("善" "恶")
          '("真" "假")
          '("高" "矮")
          '("胖" "瘦")
          '("长" "短")
          '("宽" "窄")
          '("快" "慢")
          '("远" "近")
          '("软" "硬")
          '("轻" "重")
          '("清" "浊")
          '("昼" "夜")
          '("香" "臭")
          '("深" "浅")
          '("胜" "败")
          '("干" "湿")
          '("顺" "逆")
          '("推" "拉")
          '("伸" "缩")
          '("升" "降")
          '("单" "双")
          '("奇" "偶")
          '("阴" "阳")
          '("顶" "底")
          '("粗" "细")
          '("增" "减")
          '("手" "脚")
          '("墩" "台")
          '("内" "外")

          ;下面是展会相关
          '("桌" "柜")
        )
      )
      ;多字符列表:字符串包含在另一个串字符中时,较长的写在前面
      (setq MoreSTRLst 
        (list 
          '("雪弗板字" "发光字" "即时贴")
          '("乳胶漆" "写真贴纸")
          '("内嵌" "外挂")

          ;下面是景观相关
          '("亚光面" "光面" "烧面" "烧洗面" "荔枝面" "自然面")
          '("详图" "平面图" "立面图" "剖面图" "大样图" "意向图" "效果图")
          '("园建" "给排水" "电气" "水电" "结构")
          '("索引及物料" "索引" "物料" "竖向及尺寸" "竖向设计" "尺寸定位" "坐标定位" "网格放样" "置石分布" "小品设施分布" "超荷载换填")
          
          '("尺寸标注平面图" "尺寸定位平面图")
          '("尺寸" "尺寸定位")
          
          '("铺装平面图" "物料平面图")
          '("铺装索引平面图" "索引及物料平面图")
          
          '("竖向布置平面图" "竖向设计平面图")
          '("竖向" "竖向设计")
          
          '("坐标平面图" "坐标定位平面图")

          '("网格标注平面图" "网格放样平面图")
          '("网格" "网格放样")
          
          '("置石" "置石分布")
          '("小品" "小品设施分布")
          '("不锈钢" "热镀锌" "镀锌")
          '("方通" "圆通" "扁通")
        )
      )
      (setq MatchSTRLst (append OneSTRLst MoreSTRLst));合并字符列表
    )
    (princ "\n请点选要修改的字符(左增右减): ")
    (while 
      (cond 
        ((and (setq Code (grread t 4 2))(eq (car Code) 5))
          (progn 
            (setq TgtPT    (cadr Code)
                  OriEnLst (nentselp TgtPT)
                  OriEn    (car OriEnLst)
            )
            (if 
                (and
                  (eq (length OriEnLst) 2)
                  (setq TgtObj (vlax-ename->vla-object OriEn)
                        ObjNam (Vlax-Get TgtObj 'ObjectName)
                  )
                  (or
                      (member ObjNam (list "AcDbText" "AcDbAttributeDefinition"));单行文字+属性定义
                      (and
                          (eq ObjNam "AcDbAttribute");属性文字
                          (not (wcmatch (getpropertyvalue OriEn "Value") "*\\P*"));不含换行
                          ;(= 0 (getpropertyvalue OriEn "IsMTextAttribute"));单行
                      )
                  )
                )
                (setq HasTgtObj T)
                (setq HasTgtObj nil)
            )
            T ;继续循环
          )
        )
        ((and (eq (car Code) 3) TgtObj) ;鼠标左键
          (if HasTgtObj 
            (progn 
              (if (eq ObjNam "AcDbAttributeDefinition");属性定义
                  (setq NewSTR (K:STR-AfterChange OriEn TgtPT (getpropertyvalue OriEn "TagString") MatchSTRLst T))
                  (setq NewSTR (K:STR-AfterChange OriEn TgtPT (getpropertyvalue OriEn "TextString") MatchSTRLst T))
              )

              (if NewSTR
                  (if (eq ObjNam "AcDbAttributeDefinition");属性定义
                      (Vlax-Put TgtObj 'TagString NewSTR)
                      (Vlax-Put TgtObj 'TextString NewSTR)
                  )
                  (progn
                    (princ "\n——★★★ 非数值、字母或设定列表的字符 ★★★——\n")
                    (princ "\n请点选要修改的字符(左增右减): ")
                  )
              )
              (entupd OriEn) ;更新实体
            )
            (progn
              (princ "\n——★★★ 错误：请选择单行文字、属性定义或块内单行属性文字 ★★★——\n") 
              (princ "\n请点选要修改的字符(左增右减): ")
            )
          )
          T ;;继续循环
        )
        ((and (or (eq (car Code) 11) (eq (car Code) 25)) TgtObj) ;鼠标右键
          (if HasTgtObj 
            (progn 
              (if (eq ObjNam "AcDbAttributeDefinition" )
                  (setq NewSTR (K:STR-AfterChange OriEn TgtPT (getpropertyvalue OriEn "TagString") MatchSTRLst Nil))
                  (setq NewSTR (K:STR-AfterChange OriEn TgtPT (getpropertyvalue OriEn "TextString") MatchSTRLst Nil))
              )

              (if NewSTR
                  (if (eq ObjNam "AcDbAttributeDefinition" )
                      (Vlax-Put TgtObj 'TagString NewSTR)
                      (Vlax-Put TgtObj 'TextString NewSTR)
                  )
                  (progn
                    (princ "\n——★★★ 非数值、字母或设定列表的字符 ★★★——\n")
                    (princ "\n请点选要修改的字符(左增右减): ")
                  )
              )
              (entupd OriEn) ;更新实体
            )
            (progn
              (princ "\n——★★★ 错误：请选择单行文字、属性定义或块内单行属性文字 ★★★——\n") 
              (princ "\n请点选要修改的字符(左增右减): ")
            )
          )
          T ;;继续循环
        )
      )
    )
    (if *Old_SysVar* (foreach xx *Old_SysVar* (apply 'setvar xx))) ;参数恢复
  (vla-endundomark Doc) ;结束编组 
  (princ)
)


(if (not (getenv "K\\ToolsIsExit"))
    (princ "\n——★★★ 文字增减由Kucha优化，调用命令: DZ ★★★——") 
)(princ)