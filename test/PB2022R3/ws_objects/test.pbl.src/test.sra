$PBExportHeader$test.sra
$PBExportComments$Generated Application Object
forward
global type test from application
end type
global transaction sqlca
global dynamicdescriptionarea sqlda
global dynamicstagingarea sqlsa
global error error
global message message
end forward

global type test from application
string appname = "test"
string themepath = "C:\Program Files (x86)\Appeon\PowerBuilder 19.0\IDE\theme"
string themename = "Do Not Use Themes"
boolean nativepdfvalid = false
boolean nativepdfincludecustomfont = false
string nativepdfappname = ""
long richtextedittype = 2
long richtexteditx64type = 3
long richtexteditversion = 1
string richtexteditkey = ""
string appicon = ""
string appruntimeversion = "19.2.0.2728"
end type
global test test

on test.create
appname="test"
message=create message
sqlca=create transaction
sqlda=create dynamicdescriptionarea
sqlsa=create dynamicstagingarea
error=create error
end on

on test.destroy
destroy(sqlca)
destroy(sqlda)
destroy(sqlsa)
destroy(error)
destroy(message)
end on

event open;// In the window's open event
string ls_input, ls_output
string ls_log
ls_log = "test.ini"
// Split the command line arguments into an array
string ls_cmd, ls_arg[]
integer i, li_argcnt
 
// Get the arguments and strip blanks
// from start and end of string
ls_cmd = Trim(CommandParm())
 
li_argcnt = 1
DO WHILE Len(ls_cmd) > 0
    // Find the first blank
    i = Pos( ls_cmd, " ")
 
    // If no blanks (only one argument),
    // set i to point to the hypothetical character
    // after the end of the string
    if i = 0 then i = Len(ls_cmd) + 1
 
    // Assign the arg to the argument array.
    // Number of chars copied is one less than the
    // position of the space found with Pos
    ls_arg[li_argcnt] = Left(ls_cmd, i - 1)
 
    // Increment the argument count for the next loop
    li_argcnt = li_argcnt + 1
 
    // Remove the argument from the string
    // so the next argument becomes first
    ls_cmd = Replace(ls_cmd, 1, i, "")
LOOP

// Assign the arguments to variables
if UpperBound(ls_arg) >= 1 then
    ls_input = ls_arg[1]
end if

if UpperBound(ls_arg) >= 2 then
    ls_output = ls_arg[2]
end if

nvo_pdfconverter lnvo_pdfconverter
lnvo_pdfconverter = CREATE nvo_pdfconverter

string ls_result

// First test - basic conversion
TRY
    ls_result = lnvo_pdfconverter.of_convertpdftoimage(ls_input, ls_output, 300)
	 SetProfileString ( ls_log, "test 1", "Result", ls_result )
   // messagebox("test 1", ls_result)
CATCH (RuntimeError rte1)
	SetProfileString ( ls_log, "test 1", "Error", String(rte1.Number) + " - " + rte1.Text )
    //MessageBox("Error in test 1", "Error: " + String(rte1.Number) + " - " + rte1.Text)
END TRY

// Second test - with page names
TRY
    string ls_pagenames[]
    ls_pagenames[1] = "apple"
    ls_pagenames[2] = "banana"
    ls_result = lnvo_pdfconverter.of_ConvertPdfToImageWithPageNames(ls_input, ls_output, 300, 2, ls_pagenames)
	 SetProfileString ( ls_log, "test 2", "Result", ls_result )
   // messagebox("test 2", ls_result)
CATCH (RuntimeError rte2)
	SetProfileString ( ls_log, "test 2", "Error", String(rte2.Number) + " - " + rte2.Text )
    //MessageBox("Error in test 2", "Error: " + String(rte2.Number) + " - " + rte2.Text)
END TRY

// Third test - with page names and with output paths
TRY
    string ls_output_paths[]
    ls_output_paths[1] = "alpha"
    ls_output_paths[2] = "beta"
    ls_result = lnvo_pdfconverter.of_ConvertPdfToImageWithPagenamesAndOutputPaths(ls_input, ls_output_paths, 300, 2, ls_pagenames)
	 SetProfileString ( ls_log, "test 3", "Result", ls_result )
   // messagebox("test 2", ls_result)
CATCH (RuntimeError rte3)
	SetProfileString ( ls_log, "test 3", "Error", String(rte2.Number) + " - " + rte3.Text )
    //MessageBox("Error in test 2", "Error: " + String(rte2.Number) + " - " + rte2.Text)
END TRY

open(w_test)
close(w_test)
end event

