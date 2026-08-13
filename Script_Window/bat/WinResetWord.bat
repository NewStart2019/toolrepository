:: 绑定 .docx 新版Word文档
assoc .docx=Word.Document.12
ftype Word.Document.12="C:\Program Files (x86)\Microsoft Office\root\Office16\WINWORD.EXE" "%1"

:: 绑定 .doc 旧版97-2003文档
assoc .doc=Word.Document.8
ftype Word.Document.8="C:\Program Files (x86)\Microsoft Office\root\Office16\WINWORD.EXE" "%1"

:: 可选：模板文件 .dot .dotx
assoc .dotx=Word.Template.12
ftype Word.Template.12="C:\Program Files (x86)\Microsoft Office\root\Office16\WINWORD.EXE" "%1"
assoc .dot=Word.Template.8
ftype Word.Template.8="C:\Program Files (x86)\Microsoft Office\root\Office16\WINWORD.EXE" "%1"