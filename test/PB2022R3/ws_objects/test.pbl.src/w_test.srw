$PBExportHeader$w_test.srw
forward
global type w_test from window
end type
type sle_2 from singlelineedit within w_test
end type
type sle_1 from singlelineedit within w_test
end type
type cb_1 from commandbutton within w_test
end type
end forward

global type w_test from window
integer width = 4754
integer height = 1980
boolean titlebar = true
string title = "Untitled"
boolean controlmenu = true
boolean minbox = true
boolean maxbox = true
boolean resizable = true
long backcolor = 67108864
string icon = "AppIcon!"
boolean center = true
sle_2 sle_2
sle_1 sle_1
cb_1 cb_1
end type
global w_test w_test

on w_test.create
this.sle_2=create sle_2
this.sle_1=create sle_1
this.cb_1=create cb_1
this.Control[]={this.sle_2,&
this.sle_1,&
this.cb_1}
end on

on w_test.destroy
destroy(this.sle_2)
destroy(this.sle_1)
destroy(this.cb_1)
end on

type sle_2 from singlelineedit within w_test
integer x = 805
integer y = 700
integer width = 1088
integer height = 132
integer taborder = 20
integer textsize = -12
integer weight = 400
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
long textcolor = 33554432
string text = "example.png"
borderstyle borderstyle = stylelowered!
end type

type sle_1 from singlelineedit within w_test
integer x = 777
integer y = 468
integer width = 1102
integer height = 132
integer taborder = 10
integer textsize = -12
integer weight = 400
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
long textcolor = 33554432
string text = "sample.pdf"
borderstyle borderstyle = stylelowered!
end type

type cb_1 from commandbutton within w_test
integer x = 233
integer y = 1424
integer width = 457
integer height = 132
integer taborder = 10
integer textsize = -12
integer weight = 400
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "test"
end type

event clicked;nvo_pdfconverter lnvo_pdfconverter
lnvo_pdfconverter = Create nvo_pdfconverter

string ls_result

//messagebox("debug init",lnvo_pdfconverter.of_creatondemand())

ls_result = lnvo_pdfconverter.of_convertpdftoimage(sle_1.text, sle_2.text, 300)

messagebox("test 1",ls_result)

string ls_pagenames[]
ls_pagenames[1] = "apple"
ls_pagenames[2] = "banana"
ls_result = lnvo_pdfconverter.of_ConvertPdfToImageWithPageNames(sle_1.text, sle_2.text, 300, 2, ls_pagenames)

messagebox("test 2",ls_result)
end event

