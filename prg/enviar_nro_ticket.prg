PARAMETER _nombrearchivose,nro_ticket, femodo, rucsol, usuariosol, clavesol, _urlws,ruta_cdr_local,ruta_cdr_server,ruta_rpta_server
SET STEP ON
 SET EXACT ON 
 PUBLIC rptawsticket
 rptawsticket = "ERROR"
 ls_ruc_emisor = rucsol
 ls_user = ls_ruc_emisor+usuariosol
 ls_pwd_sol = clavesol

 TEXT TO ls_envioxml TEXTMERGE NOSHOW PRETEXT 0015 FLAGS 1
	<soapenv:Envelope xmlns:ser="http://service.sunat.gob.pe" xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
			xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">			
	<soapenv:Header>
		<wsse:Security>
	 		<wsse:UsernameToken>
	 			<wsse:Username><<ls_user>></wsse:Username>
	 			<wsse:Password><<ls_pwd_sol>></wsse:Password>
			</wsse:UsernameToken>
	 	</wsse:Security>
	 </soapenv:Header>
	 <soapenv:Body>
		 <ser:getStatus>
	 		<ticket><<nro_ticket>></ticket>
	 	</ser:getStatus>
	 </soapenv:Body>
	</soapenv:Envelope>

 ENDTEXT
 oxmlhttp = CREATEOBJECT("MSXML2.ServerXMLHTTP.6.0")
 oxmlbody = CREATEOBJECT('MSXML2.DOMDocument.6.0')
 IF  .NOT. (oxmlbody.loadxml(ls_envioxml))
    oresp.mensaje = "No se cargo XML: "+oxmlbody.parseerror.reason
    *RETURN .F.
    RETURN "<message>Error: Comprobante NO SE HA ENVIADO - NO SE CARGO XML</message>"
 ENDIF
 lsurl = purlws
 oxmlhttp.open('POST', lsurl, .F.)
 oxmlhttp.setrequestheader("Content-Type", "text/xml")
 oxmlhttp.setrequestheader("Content-Type", "text/xml;charset=ISO-8859-1")
 oxmlhttp.setrequestheader("Content-Length", LEN(ls_envioxml))
 oxmlhttp.setrequestheader("SOAPAction", "getStatus")
 oxmlhttp.setoption(2, 13056) 
 
 lcErr = "" 
TRY 
 oxmlhttp.send(oxmlbody.documentelement.xml)

CATCH TO loError 
	lcErr = [Error: ] + STR(loError.ERRORNO) + CHR(13) + [Linea: ] + STR(loError.LINENO) + CHR(13) + [Mensaje: ] + loError.MESSAGE 
FINALLY 
	IF EMPTY(lcErr) 
		*MESSAGEBOX("El mensaje se envi� con �xito", 64, "Aviso") 
	ELSE 
		MESSAGEBOX(lcErr, 16 , "Error")
	ENDIF 
ENDTRY 

IF lcerr=""
ELSE
	*RETURN "ERROR- ASEGURE QUE HAY CONEXION A INTENET O ESTE DISPONIBLE EL SERVIDOR EL COMPROBANTE NO SE ENVIO" 
	*RETURN 0
	RETURN "<message>ERROR - NO QUE HAY CONEXION A INTERNET O  EL SERVIDOR NO ESTA DISPONIBLE, EL COMPROBANTE NO SE ENVIO</message> <httpstatus>500</httpstatus>"
ENDIF

 
 SET STEP ON
 IF (oxmlhttp.status<>200)
 	*MESSAGEBOX("ERROR:"+ oxmlhttp.responsetext )
 	Vlc_faultcode = STREXTRACT(oxmlhttp.responsetext, "<statusCode>", "</statusCode>")
    Vlc_faultstring= STREXTRACT(oxmlhttp.responsetext, "<content>", "</content>")
    Vlc_message= STREXTRACT(oxmlhttp.responsetext, "<message>", "</message>")
    
    RETURN "<message>Error: Comprobante NO SE HA ENVIADO - ' + Vlc_faultcode + '</message>, ERROR: <httpstatus>"+ALLTRIM(STR(oxmlhttp.status))+"</httpstatus>"+ +NVL(oxmlhttp.responsetext, '')
    *RETURN 0
 ELSE
    loxmlresp = CREATEOBJECT("MSXML2.DOMDocument.6.0")
    loxmlresp.loadxml(oxmlhttp.responsetext)
    ccontenidorptazip = STREXTRACT(oxmlhttp.responsetext, "<content>", "</content>")
    
    Vlc_faultcode = ALLTRIM(STREXTRACT(oxmlhttp.responsetext, "<statusCode>", "</statusCode>"))
    Vlc_faultstring= STREXTRACT(oxmlhttp.responsetext, "<content>", "</content>")
    Vlc_message= STREXTRACT(oxmlhttp.responsetext, "<message>", "</message>")
    
    IF EMPTY(Vlc_faultcode) OR  Vlc_faultcode = '0' &&AND EMPTY(Vlc_faultstring) AND EMPTY(Vlc_message) THEN
	    DELETE FILE ALLTRIM(ruta_cdr_local+"R-"+_nombrearchivose+".zip")
	    STRTOFILE(STRCONV(ccontenidorptazip, 14), ruta_cdr_local+"R-"+_nombrearchivose+".zip")
	    
	    IF Vgc_localmente = 1 THEN 	    
		    DELETE FILE ALLTRIM(ruta_cdr_server+"R-"+_nombrearchivose+".zip")
		    STRTOFILE(STRCONV(ccontenidorptazip, 14), ruta_cdr_server+"R-"+_nombrearchivose+".zip") 
		    
		    DELETE FILE ALLTRIM(ruta_rpta_server+"R-"+_nombrearchivose+".zip")
		    STRTOFILE(STRCONV(ccontenidorptazip, 14), ruta_rpta_server+"R-"+_nombrearchivose+".zip")
		ENDIF 
	    
	    Vlc_ruta_CDR = ''
	    IF Vgc_localmente = 1 THEN 
		    IF FILE(ruta_cdr_local+"R-"+_nombrearchivose+".zip")	
				Vlc_ruta_CDR = ruta_cdr_local							
			ENDIF
		ENDIF 
		
		IF EMPTY(Vlc_ruta_CDR)
			IF FILE(ruta_rpta_server+"R-"+_nombrearchivose+".zip")	
				Vlc_ruta_CDR = ruta_rpta_server							
			ENDIF 
		ENDIF 
	    
	    Vlc_CDR = leer_cdr(Vlc_ruta_CDR+"R-"+_nombrearchivose+".zip",Vlc_ruta_CDR,"R-"+_nombrearchivose+".xml")	   
	    
	    Vlc_codigo_CDR = ALLTRIM(STREXTRACT(Vlc_CDR, "<CodigoResCDR>", "</CodigoResCDR>"))
	    Vlc_response_CDR = STREXTRACT(Vlc_CDR, "<ResponseCDR>", "</ResponseCDR>")
	    
	    IF Vlc_codigo_CDR = '0' THEN 
	    	DELETE FILE ALLTRIM(Vlc_ruta_CDR+"R-"+_nombrearchivose+".xml")
	    	oFSO = CREATEOBJECT("Scripting.FileSystemObject")
			oFSO.DeleteFolder(Vlc_ruta_CDR+"dummy")
	    	*DELETE FOLDER ALLTRIM(Vlc_ruta_CDR+"dummy")
	    	RETURN '<message>'+Vlc_response_CDR+'</message> '+'<httpstatus>'+ALLTRIM(STR(oxmlhttp.status))+'</httpstatus>'+'-'+NVL(oxmlhttp.responsetext, '')
	    ENDIF
	    
	    IF Vlc_codigo_CDR <> '0' THEN 
	    	RETURN '<message>Error: Comprobante NO SE HA ENVIADO - '+Vlc_response_CDR+'</message> '+'<httpstatus>400</httpstatus>'+'-'+NVL(oxmlhttp.responsetext, '')
	    ENDIF 
	      
	    *STRTOFILE(STRCONV(ccontenidorptazip, 14), _rutaxml_cdr+"R-"+_nombrearchivose_CLIENTE+".zip")
	    *STRTOFILE(STRCONV(ccontenidorptazip, 14), _rutaxml_cdr_server+"R-"+_nombrearchivose_CLIENTE+".zip")  
	    *MESSAGEBOX(oxmlhttp.responsetext)
	    *RETURN "COMPROBANTE ENVIADO Y ACEPTADO"
	    *RETURN '<message>ENVIADO Y ACEPTADO</message> '+'<httpstatus>'+ALLTRIM(STR(oxmlhttp.status))+'</httpstatus>'+'-'+NVL(oxmlhttp.responsetext, '')
	    * rptawsticket = 
	 ELSE
	 	RETURN '<message>Error: Comprobante NO SE HA ENVIADO - ' +Vlc_faultstring+ '</message> '+'<httpstatus>400</httpstatus>'+'-'+NVL(oxmlhttp.responsetext, '')
	 ENDIF
 ENDIF
 SET EXACT OFF 



	