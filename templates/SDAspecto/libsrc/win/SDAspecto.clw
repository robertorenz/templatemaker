!-----------------------------------------------------------------------------!
!  SDAspecto - Motor de reglas de aspecto visual                              !
!  Adrian E. Santarelli - SDigitales                                          !
!-----------------------------------------------------------------------------!
    MEMBER()
    INCLUDE('EQUATES.CLW'),ONCE
    INCLUDE('SDAspecto.INC'),ONCE
    MAP
      MODULE('WINAPI')
!-- Clarion no expone WM_SETREDRAW por PROP, asi que se va por API. Es la
!-- forma estandar de Windows para hacer muchos cambios de layout sin que se
!-- repinte en cada uno: se apaga el redibujado, se mueve todo, y se repinta
!-- una sola vez al final.
!-- OJO: los prototipos van INDENTADOS. En columna 1 el compilador los lee
!-- como una declaracion de datos (label + tipo + atributos) y tira
!-- "Unknown attribute" por cada parametro.
        SDA:SendMessage(UNSIGNED hWnd, ULONG uMsg, LONG wParam, LONG lParam),LONG,RAW,PASCAL,NAME('SendMessageA'),PROC
        SDA:RedrawWindow(UNSIGNED hWnd, LONG lprcUpdate, UNSIGNED hrgnUpdate, UNSIGNED flags),BYTE,RAW,PASCAL,NAME('RedrawWindow'),PROC
      END
    END!MAP

WM_SETREDRAW            EQUATE(000Bh)
RDW_INVALIDATE          EQUATE(0001h)
RDW_ERASE               EQUATE(0004h)
RDW_ALLCHILDREN         EQUATE(0080h)
RDW_UPDATENOW           EQUATE(0100h)
RDW_FRAME               EQUATE(0400h)
!-- Repintado completo: la ventana, su marco y TODOS los hijos, ya mismo.
!-- Sin RDW_ALLCHILDREN los controles quedan en blanco al descongelar.
RDW_TODO                EQUATE(0001h + 0004h + 0080h + 0100h + 0400h)

!-----------------------------------------------------------------------------!
!  Estado por ventana.
!  ,THREAD porque la instancia de la clase es global y compartida: cada thread
!  (cada ventana MDI) necesita su propia lista de controles omitidos.
!-----------------------------------------------------------------------------!
SDWinState              SDWinStateQType,THREAD

!-- Handle (HWND) de la ventana a la que pertenece el estado de arriba.
!-- IMPRESCINDIBLE: en ABC un formulario de actualizacion corre en el MISMO
!-- thread que el browse que lo llamo, y los FEQ se renumeran por ventana.
!-- Sin esta comprobacion el form encuentra en la queue los FEQ del browse ya
!-- capturados, no vuelve a tomar snapshot, y termina aplicandose la geometria
!-- de los controles del browse. Se veia como un layout completamente roto la
!-- primera vez y correcto al reabrir (porque el Kill ya habia vaciado todo).
SDWinHandle             LONG,THREAD

!-- Geometria y tipografia de la ventana en curso. Estaba como propiedades de
!-- la clase, y ahi estaba MAL: la instancia es unica y global, asi que dos
!-- ventanas abriendose en threads distintos se pisaban los valores. La segunda
!-- sobreescribia Orig* entre el snapshot y la restauracion de la primera, y la
!-- primera terminaba haciendo SETPOSITION y PROP:MinWidth con las medidas de
!-- la otra ventana. Con FteVieja era peor: la ventana de tiempo en que se la
!-- usa es TODO el recorrido de controles.
!-- Es estado por ventana, igual que SDWinState, y ahora vive donde corresponde.
!-- OJO con la sintaxis: un GROUP,TYPE se instancia con GROUP(Tipo) ... END.
!-- La forma corta "SDWinGeo SDWinGeoType" solo vale para QUEUE,TYPE y
!-- CLASS,TYPE - de ahi que SDWinState de arriba se declare de esa forma.
SDWinGeo                GROUP(SDWinGeoType),THREAD
                        END

!-- Archivo de diagnostico. Se usa un archivo y no MESSAGE porque el cartel se
!-- trunca y ademas MESSAGE trata la barra vertical como salto de linea, que es
!-- justo el delimitador de las listas del motor.
!-- ,THREAD en los dos: un FILE compartido entre threads necesita su propio
!-- bloque de control por thread, o el segundo OPEN falla y ademas se pisa el
!-- buffer de registro.
SDDiagName              CSTRING(261),THREAD
SDDiagFile              FILE,DRIVER('ASCII'),NAME(SDDiagName),CREATE,THREAD,PRE(SDD)
Record                    RECORD
Linea                       STRING(500)
                          END
                        END

!-----------------------------------------------------------------------------!
!  Construccion / destruccion
!-----------------------------------------------------------------------------!
SDAspectoClass.Construct PROCEDURE()
  CODE
  SELF.Reglas &= NEW SDRuleQType
  SELF.Deshabilitado = 0
  SELF.Diagnostico   = 0
  SELF.Esquema       = ''
  SELF.IniFile       = ''
  SELF.ModoRequerido = sdReq:Ambos
  !-- Convencion: -1 y cadena vacia = no tocar.
  SELF.FuenteActiva     = 0
  SELF.FuenteAVentana   = 1
  SELF.FuenteAControles = 1
  SELF.FuenteNombre     = ''
  SELF.FuenteTamano     = -1
  SELF.FuenteEstilo     = -1
  SELF.FuenteColor      = -1
  SELF.FuenteCharset    = -1
  !-- Ajustes fijos: -1 = no aplicar
  SELF.AltoMinimo        = 0
  SELF.ColorTab          = -1
  SELF.ColorSheet        = -1
  SELF.ColorPanel        = -1
  SELF.ColorRegion       = -1
  SELF.ColorList         = -1
  SELF.ColorCombo        = -1
  SELF.ColorOption       = -1
  SELF.ColorSpin         = -1
  SELF.ColorText         = -1
  SELF.RescalarActivo    = 0
  SELF.RescalarVentana   = 1
  SELF.RecentrarVentana  = 1
  SELF.PreservarMenu     = 1
  SELF.PreservarToolbar  = 1
  !-- Congelado de repintado: APAGADO. Ver CongelarPintura().
  SELF.CongelarActivo    = 0
  !-- Convivencia con el resizer de ABC: ENCENDIDO. No tocar PROP:MinWidth ni
  !-- PROP:MinHeight es inofensivo aunque la ventana no tenga resizer -son los
  !-- minimos que ya traia del disenador- y evita romper la que si lo tiene.
  SELF.RespetarResizer   = 1
  !-- El lock protege SELF.Reglas. Se crea primero que nada: cualquier metodo
  !-- que lo tome antes de tiempo se encuentra con NULL y sigue sin bloquear,
  !-- pero en Construct todavia no hay otro thread mirando.
  SELF.Lock &= NewCriticalSection()


SDAspectoClass.Destruct PROCEDURE()
  CODE
  IF NOT SELF.Reglas &= NULL
    FREE(SELF.Reglas)
    DISPOSE(SELF.Reglas)
    SELF.Reglas &= NULL
  END
  IF NOT SELF.Lock &= NULL
    SELF.Lock.Kill()
    SELF.Lock &= NULL
  END


!-----------------------------------------------------------------------------!
!  Exclusion mutua sobre la queue de reglas.
!
!  Clarion NO protege una QUEUE compartida entre threads: hay un solo buffer de
!  registro por queue, asi que dos GET concurrentes se pisan, y un FREE o un
!  DELETE mientras otro thread itera lo deja recorriendo memoria liberada.
!
!  Se toleran llamadas con el lock en NULL (instancia a medio construir) para
!  que nunca sea la causa de un GPF.
!-----------------------------------------------------------------------------!
SDAspectoClass.Bloquear PROCEDURE()
  CODE
  IF NOT SELF.Lock &= NULL
    SELF.Lock.Wait()
  END


SDAspectoClass.Liberar PROCEDURE()
  CODE
  IF NOT SELF.Lock &= NULL
    SELF.Lock.Release()
  END


SDAspectoClass.Init PROCEDURE(STRING pEsquema)
  CODE
  SELF.Esquema = CLIP(pEsquema)


SDAspectoClass.Kill PROCEDURE()
  CODE
  SELF.Bloquear()
  IF NOT SELF.Reglas &= NULL
    FREE(SELF.Reglas)
  END
  SELF.Liberar()

!-----------------------------------------------------------------------------!
!  Persistencia en INI
!
!  Estructura del archivo:
!
!    [SDAspecto]        parametros globales (tipografia, rescalado, etc)
!    Reglas=13          cuantas secciones [Regla:n] hay
!    [Regla:1] .. [Regla:13]   una por regla, con todos sus campos
!
!  CargarIni solo reemplaza las reglas si el archivo declara alguna. Si el
!  INI no existe, o no tiene la clave Reglas, quedan las que genero el
!  template. Asi el archivo es opcional y funciona como override.
!-----------------------------------------------------------------------------!
SDAspectoClass.CargarIni PROCEDURE(<STRING pArchivo>)
lArch       CSTRING(261)
lSec        CSTRING(41)
lCant       LONG
lI          LONG
  CODE
  IF OMITTED(pArchivo) OR NOT LEN(CLIP(pArchivo))
    lArch = CLIP(SELF.IniFile)
  ELSE
    lArch = CLIP(pArchivo)
    SELF.IniFile = lArch
  END
  IF NOT LEN(lArch) THEN RETURN 0.

  !-- IMPRESCINDIBLE: si el archivo NO existe, GETINI devuelve cadena vacia
  !-- IGNORANDO el default (asi esta documentado). Sin este corte, un INI
  !-- inexistente pondria todos los parametros en cero en vez de dejar los
  !-- valores que genero el template.
  IF NOT EXISTS(lArch) THEN RETURN 0.

  !-- Globales. El valor actual va como default, asi una clave ausente en el
  !-- INI deja lo que ya estaba en vez de ponerlo en cero.
  SELF.Esquema          = GETINI('SDAspecto','Esquema',          CLIP(SELF.Esquema),      lArch)
  SELF.Diagnostico      = GETINI('SDAspecto','Diagnostico',      SELF.Diagnostico,        lArch)
  SELF.ModoRequerido    = GETINI('SDAspecto','ModoRequerido',    SELF.ModoRequerido,      lArch)

  SELF.FuenteActiva     = GETINI('SDAspecto','FuenteActiva',     SELF.FuenteActiva,       lArch)
  SELF.FuenteNombre     = GETINI('SDAspecto','FuenteNombre',     CLIP(SELF.FuenteNombre), lArch)
  SELF.FuenteTamano     = GETINI('SDAspecto','FuenteTamano',     SELF.FuenteTamano,       lArch)
  SELF.FuenteEstilo     = GETINI('SDAspecto','FuenteEstilo',     SELF.FuenteEstilo,       lArch)
  SELF.FuenteColor      = GETINI('SDAspecto','FuenteColor',      SELF.FuenteColor,        lArch)
  SELF.FuenteCharset    = GETINI('SDAspecto','FuenteCharset',    SELF.FuenteCharset,      lArch)
  SELF.FuenteAVentana   = GETINI('SDAspecto','FuenteAVentana',   SELF.FuenteAVentana,     lArch)
  SELF.FuenteAControles = GETINI('SDAspecto','FuenteAControles', SELF.FuenteAControles,   lArch)

  !-- ajustes fijos
  SELF.AltoMinimo       = GETINI('SDAspecto','AltoMinimo',       SELF.AltoMinimo,         lArch)
  SELF.ColorTab         = GETINI('SDAspecto','ColorTab',         SELF.ColorTab,           lArch)
  SELF.ColorSheet       = GETINI('SDAspecto','ColorSheet',       SELF.ColorSheet,         lArch)
  SELF.ColorPanel       = GETINI('SDAspecto','ColorPanel',       SELF.ColorPanel,         lArch)
  SELF.ColorRegion      = GETINI('SDAspecto','ColorRegion',      SELF.ColorRegion,        lArch)
  SELF.ColorList        = GETINI('SDAspecto','ColorList',        SELF.ColorList,          lArch)
  SELF.ColorCombo       = GETINI('SDAspecto','ColorCombo',       SELF.ColorCombo,         lArch)
  SELF.ColorOption      = GETINI('SDAspecto','ColorOption',      SELF.ColorOption,        lArch)
  SELF.ColorSpin        = GETINI('SDAspecto','ColorSpin',        SELF.ColorSpin,          lArch)
  SELF.ColorText        = GETINI('SDAspecto','ColorText',        SELF.ColorText,          lArch)

  SELF.RescalarActivo   = GETINI('SDAspecto','RescalarActivo',   SELF.RescalarActivo,     lArch)
  SELF.RescalarVentana  = GETINI('SDAspecto','RescalarVentana',  SELF.RescalarVentana,    lArch)
  SELF.RecentrarVentana = GETINI('SDAspecto','RecentrarVentana', SELF.RecentrarVentana,   lArch)
  SELF.PreservarMenu    = GETINI('SDAspecto','PreservarMenu',    SELF.PreservarMenu,      lArch)
  SELF.PreservarToolbar = GETINI('SDAspecto','PreservarToolbar', SELF.PreservarToolbar,   lArch)

  !-- Reglas. Solo se reemplazan si el archivo declara al menos una.
  lCant = GETINI('SDAspecto','Reglas', 0, lArch)
  IF lCant <= 0 THEN RETURN 1.
  IF SELF.Reglas &= NULL THEN RETURN 1.

  !-- El lock se toma recien aca, sobre el bloque que toca la queue, y no antes:
  !-- asi ninguno de los RETURN de arriba lo puede dejar tomado.
  SELF.Bloquear()
  FREE(SELF.Reglas)
  LOOP lI = 1 TO lCant
    lSec = 'Regla:' & lI
    CLEAR(SELF.Reglas)
    SELF.Reglas.Nombre       = GETINI(lSec,'Nombre','',  lArch)
    SELF.Reglas.Orden        = lI
    SELF.Reglas.Activa       = GETINI(lSec,'Activa',1,   lArch)
    !-- Tipos y Texto se guardan en formato humano (separados por coma) y se
    !-- normalizan al leerlos, para que el INI se pueda editar a mano.
    SELF.Reglas.Tipos        = SELF.PipeList(GETINI(lSec,'Tipos','', lArch))
    SELF.Reglas.Texto        = SELF.PipeList(GETINI(lSec,'Texto','', lArch))
    SELF.Reglas.ModoTexto    = GETINI(lSec,'ModoTexto',0,  lArch)
    SELF.Reglas.Picture      = GETINI(lSec,'Picture','',   lArch)
    SELF.Reglas.TestReq      = GETINI(lSec,'TestReq',0,    lArch)
    SELF.Reglas.TestReadOnly = GETINI(lSec,'TestReadOnly',0, lArch)
    SELF.Reglas.TestDisable  = GETINI(lSec,'TestDisable',0,  lArch)
    SELF.Reglas.Acciones     = GETINI(lSec,'Acciones',0,   lArch)
    SELF.Reglas.Background   = GETINI(lSec,'Color',0,      lArch)
    SELF.Reglas.FontColor    = GETINI(lSec,'FontColor',0,  lArch)
    SELF.Reglas.FontStyle    = GETINI(lSec,'FontStyle',0,  lArch)
    SELF.Reglas.Flat         = GETINI(lSec,'Flat',0,       lArch)
    SELF.Reglas.Tip          = GETINI(lSec,'Tip','',       lArch)
    SELF.Reglas.Cursor       = GETINI(lSec,'Cursor','',    lArch)
    SELF.Reglas.Cortar       = GETINI(lSec,'Cortar',0,     lArch)
    ADD(SELF.Reglas)
  END
  SELF.Liberar()
  RETURN 1


SDAspectoClass.GuardarIni PROCEDURE(<STRING pArchivo>)
lArch       CSTRING(261)
lSec        CSTRING(41)
lI          LONG
lPrevias    LONG
  CODE
  IF OMITTED(pArchivo) OR NOT LEN(CLIP(pArchivo))
    lArch = CLIP(SELF.IniFile)
  ELSE
    lArch = CLIP(pArchivo)
    SELF.IniFile = lArch
  END
  IF NOT LEN(lArch) THEN RETURN 0.

  !-- Cuantas reglas habia antes: si ahora hay menos, las secciones sobrantes
  !-- quedarian huerfanas en el archivo. Se borran al final.
  lPrevias = GETINI('SDAspecto','Reglas', 0, lArch)

  PUTINI('SDAspecto','Esquema',          CLIP(SELF.Esquema),      lArch)
  PUTINI('SDAspecto','Diagnostico',      SELF.Diagnostico,        lArch)
  PUTINI('SDAspecto','ModoRequerido',    SELF.ModoRequerido,      lArch)

  PUTINI('SDAspecto','FuenteActiva',     SELF.FuenteActiva,       lArch)
  PUTINI('SDAspecto','FuenteNombre',     CLIP(SELF.FuenteNombre), lArch)
  PUTINI('SDAspecto','FuenteTamano',     SELF.FuenteTamano,       lArch)
  PUTINI('SDAspecto','FuenteEstilo',     SELF.FuenteEstilo,       lArch)
  PUTINI('SDAspecto','FuenteColor',      SELF.FuenteColor,        lArch)
  PUTINI('SDAspecto','FuenteCharset',    SELF.FuenteCharset,      lArch)
  PUTINI('SDAspecto','FuenteAVentana',   SELF.FuenteAVentana,     lArch)
  PUTINI('SDAspecto','FuenteAControles', SELF.FuenteAControles,   lArch)

  PUTINI('SDAspecto','AltoMinimo',       SELF.AltoMinimo,         lArch)
  PUTINI('SDAspecto','ColorTab',         SELF.ColorTab,           lArch)
  PUTINI('SDAspecto','ColorSheet',       SELF.ColorSheet,         lArch)
  PUTINI('SDAspecto','ColorPanel',       SELF.ColorPanel,         lArch)
  PUTINI('SDAspecto','ColorRegion',      SELF.ColorRegion,        lArch)
  PUTINI('SDAspecto','ColorList',        SELF.ColorList,          lArch)
  PUTINI('SDAspecto','ColorCombo',       SELF.ColorCombo,         lArch)
  PUTINI('SDAspecto','ColorOption',      SELF.ColorOption,        lArch)
  PUTINI('SDAspecto','ColorSpin',        SELF.ColorSpin,          lArch)
  PUTINI('SDAspecto','ColorText',        SELF.ColorText,          lArch)

  PUTINI('SDAspecto','RescalarActivo',   SELF.RescalarActivo,     lArch)
  PUTINI('SDAspecto','RescalarVentana',  SELF.RescalarVentana,    lArch)
  PUTINI('SDAspecto','RecentrarVentana', SELF.RecentrarVentana,   lArch)
  PUTINI('SDAspecto','PreservarMenu',    SELF.PreservarMenu,      lArch)
  PUTINI('SDAspecto','PreservarToolbar', SELF.PreservarToolbar,   lArch)

  IF SELF.Reglas &= NULL
    PUTINI('SDAspecto','Reglas', 0, lArch)
    RETURN 1
  END

  !-- Desde aca se recorre la queue: bajo lock, y sin ningun RETURN adentro.
  SELF.Bloquear()
  PUTINI('SDAspecto','Reglas', RECORDS(SELF.Reglas), lArch)

  LOOP lI = 1 TO RECORDS(SELF.Reglas)
    GET(SELF.Reglas, lI)
    IF ERRORCODE() THEN CYCLE.
    lSec = 'Regla:' & lI
    PUTINI(lSec,'Nombre',       CLIP(SELF.Reglas.Nombre),  lArch)
    PUTINI(lSec,'Activa',       SELF.Reglas.Activa,        lArch)
    !-- en formato editable a mano: coma en vez de barra
    PUTINI(lSec,'Tipos',        SELF.ComaLista(SELF.Reglas.Tipos), lArch)
    PUTINI(lSec,'Texto',        SELF.ComaLista(SELF.Reglas.Texto), lArch)
    PUTINI(lSec,'ModoTexto',    SELF.Reglas.ModoTexto,     lArch)
    PUTINI(lSec,'Picture',      CLIP(SELF.Reglas.Picture), lArch)
    PUTINI(lSec,'TestReq',      SELF.Reglas.TestReq,       lArch)
    PUTINI(lSec,'TestReadOnly', SELF.Reglas.TestReadOnly,  lArch)
    PUTINI(lSec,'TestDisable',  SELF.Reglas.TestDisable,   lArch)
    PUTINI(lSec,'Acciones',     SELF.Reglas.Acciones,      lArch)
    PUTINI(lSec,'Color',        SELF.Reglas.Background,    lArch)
    PUTINI(lSec,'FontColor',    SELF.Reglas.FontColor,     lArch)
    PUTINI(lSec,'FontStyle',    SELF.Reglas.FontStyle,     lArch)
    PUTINI(lSec,'Flat',         SELF.Reglas.Flat,          lArch)
    PUTINI(lSec,'Tip',          CLIP(SELF.Reglas.Tip),     lArch)
    PUTINI(lSec,'Cursor',       CLIP(SELF.Reglas.Cursor),  lArch)
    PUTINI(lSec,'Cortar',       SELF.Reglas.Cortar,        lArch)
  END

  !-- Borrar las secciones que sobran de un guardado anterior con mas reglas.
  !-- PUTINI con entry y value omitidos elimina la seccion entera.
  LOOP lI = RECORDS(SELF.Reglas) + 1 TO lPrevias
    PUTINI('Regla:' & lI, , , lArch)
  END
  SELF.Liberar()
  RETURN 1

!-----------------------------------------------------------------------------!
!  Esquema de fabrica
!
!  Las reglas son CONDICIONALES. El alto minimo y el color base por tipo no lo
!  son: se aplican siempre, como la tipografia, y por eso viven como
!  propiedades de la clase (ver AplicarFijos), no como reglas.
!
!  Ajustes fijos:  AltoMinimo, ColorTab/Sheet/Panel/Region/List/Combo/
!                  Option/Spin/Text
!                  (no hay ColorGroup: un GROUP no es superficie rellenable)
!
!  Reglas (todas cortan, semantica IF/ELSIF):
!    1. Obligatorios   <- UN color para todos los tipos
!    2. SoloLectura
!    3. Botones        <- por texto
!-----------------------------------------------------------------------------!
SDAspectoClass.CargarDefaults PROCEDURE()
lR          LONG
  CODE
  !-- OJO: aca NO se tocan los ajustes fijos (AltoMinimo, ColorXxx). Esos los
  !-- pone el template antes de llamar a Arrancar(), y el INI los puede pisar.
  !-- Si CargarDefaults los reescribiera, el boton "Restaurar fabrica" de la
  !-- ventana borraria la configuracion de tipografia y colores base.
  IF SELF.Reglas &= NULL THEN RETURN.

  !-- Todo el rearmado bajo lock: el boton "Restaurar fabrica" de la ventana de
  !-- configuracion llega hasta aca con otras ventanas MDI abiertas, y sin esto
  !-- el FREE deja a cualquier thread que este iterando sobre memoria liberada.
  !-- Los AddRule/Set* de abajo vuelven a tomarlo; es re-entrante para el mismo
  !-- thread (CRITICAL_SECTION de Windows lleva cuenta de recursion).
  SELF.Bloquear()
  FREE(SELF.Reglas)

  !-- 1) Obligatorios. UN solo color para todos los tipos.
  !--    CHECK queda afuera a proposito.
  !--    LIST y los COMBO no tienen atributo REQ: se detectan porque el
  !--    disenador les puso un color de fondo (ver ModoRequerido).
  lR = SELF.AddRule('Obligatorios','ENTRY,SPIN,TEXT,LIST,COMBO,DROPCOMBO,DROPLIST')
  SELF.SetMatch(lR, sdTest:Si, sdTest:Ignorar, sdTest:Ignorar)
  SELF.SetAccion(lR, sdAct:Color, 00E0F0FFh)
  SELF.SetCortar(lR, 1)

  !-- 2) Solo lectura, gris unificado. Va DESPUES de obligatorios: un campo
  !--    que es las dos cosas se pinta como obligatorio.
  lR = SELF.AddRule('SoloLectura','ENTRY,SPIN,TEXT,LIST,COMBO,DROPCOMBO,DROPLIST')
  SELF.SetMatch(lR, sdTest:Ignorar, sdTest:Si, sdTest:Ignorar)
  SELF.SetAccion(lR, sdAct:Color, 00F0F0F0h)
  SELF.SetCortar(lR, 1)

  !-- 3) Normales: ni requerido, ni solo lectura, ni deshabilitado. Va tercera
  !--    y cierra la cadena IF/ELSIF de los controles de edicion, dandoles un
  !--    fondo explicito. Sin esto quedan transparentes y heredan el color del
  !--    contenedor que tengan atras (tipicamente un GROUP).
  lR = SELF.AddRule('Normales','ENTRY,SPIN,TEXT,LIST,COMBO,DROPCOMBO,DROPLIST')
  SELF.SetMatch(lR, sdTest:No, sdTest:No, sdTest:No)
  SELF.SetAccion(lR, sdAct:Color, 16777215)
  SELF.SetCortar(lR, 1)

  !-- 4) Botones por texto. Tonos palidos a proposito.
  !-- Las reglas de boton usan el mismo sdAct:Color que todas: PintarFondo lo
  !-- rutea a PROP:FontColor porque el control es un BUTTON. Por eso los tonos
  !-- son saturados y oscuros - se leen sobre el gris del boton nativo.
  lR = SELF.AddRule('BotonConfirmar','BUTTON')
  SELF.SetTexto(lR, 'OK,SI,ACEPTAR,GUARDAR,GRABAR,APLICAR,IMPRIMIR,RECARGAR', sdText:Exacto)
  SELF.SetAccion(lR, sdAct:Color, 0008000h)          !-- verde oscuro
  SELF.SetCortar(lR, 1)

  lR = SELF.AddRule('BotonCancelar','BUTTON')
  SELF.SetTexto(lR, 'CANCELAR,CERRAR,SALIR,NO', sdText:Exacto)
  SELF.SetAccion(lR, sdAct:Color, 00000C0h)          !-- rojo oscuro
  SELF.SetCortar(lR, 1)

  !-- Botones de accion de un browse. Va DESPUES de confirmar/cancelar: si
  !-- alguno de esos matcheo, ya corto y no llega hasta aca.
  lR = SELF.AddRule('BotonesBrowse','BUTTON')
  SELF.SetTexto(lR, 'AGREGAR,MODIFICAR,BORRAR,VER,CONSULTA,EXPORTAR,COPIAR', sdText:Exacto)
  SELF.SetAccion(lR, sdAct:Color, 0A00000h)          !-- azul oscuro
  SELF.SetCortar(lR, 1)

  SELF.Liberar()


SDAspectoClass.Arrancar PROCEDURE(STRING pArchivo)
  CODE
  SELF.IniFile = CLIP(pArchivo)
  SELF.CargarIni()
  IF SELF.Reglas &= NULL THEN RETURN.
  !-- Si el INI trajo reglas, mandan esas y no se toca nada mas.
  IF RECORDS(SELF.Reglas) THEN RETURN.
  !-- No habia archivo, o no traia reglas: esquema de fabrica, y se graba para
  !-- que quede el punto de partida editable.
  SELF.CargarDefaults()
  SELF.GuardarIni()

!-----------------------------------------------------------------------------!
!  Carga de reglas
!-----------------------------------------------------------------------------!
!-- AddRule se protege sola porque la ventana de configuracion la llama en
!-- runtime (boton Agregar) con otras ventanas MDI abiertas.
!-- Los Set* de mas abajo NO llevan lock a proposito: solo se llegan desde
!-- CargarDefaults (que ya lo tiene tomado) o desde el arranque del programa,
!-- que es monothread. Si alguna vez se los llama desde una ventana, hay que
!-- envolver la llamada en Bloquear() ... Liberar().
SDAspectoClass.AddRule PROCEDURE(STRING pNombre, STRING pTipos)
  CODE
  SELF.Bloquear()
  CLEAR(SELF.Reglas)
  SELF.Reglas.Nombre       = pNombre
  SELF.Reglas.Tipos        = SELF.PipeList(pTipos)
  SELF.Reglas.Activa       = 1
  SELF.Reglas.TestReq      = sdTest:Ignorar
  SELF.Reglas.TestReadOnly = sdTest:Ignorar
  SELF.Reglas.TestDisable  = sdTest:Ignorar
  SELF.Reglas.ModoTexto    = sdText:Exacto
  SELF.Reglas.Acciones     = 0
  SELF.Reglas.Cortar         = 0
  ADD(SELF.Reglas)
  IF ERRORCODE()
    SELF.Liberar()
    RETURN 0
  END
  SELF.Reglas.Orden = RECORDS(SELF.Reglas)
  PUT(SELF.Reglas)
  SELF.Liberar()
  RETURN RECORDS(SELF.Reglas)


SDAspectoClass.SetMatch PROCEDURE(LONG pRegla, BYTE pReq, BYTE pReadOnly, BYTE pDisable)
  CODE
  GET(SELF.Reglas, pRegla)
  IF ERRORCODE() THEN RETURN.
  SELF.Reglas.TestReq      = pReq
  SELF.Reglas.TestReadOnly = pReadOnly
  SELF.Reglas.TestDisable  = pDisable
  PUT(SELF.Reglas)


SDAspectoClass.SetTexto PROCEDURE(LONG pRegla, STRING pTextos, BYTE pModo)
  CODE
  GET(SELF.Reglas, pRegla)
  IF ERRORCODE() THEN RETURN.
  SELF.Reglas.Texto     = SELF.PipeList(pTextos)
  SELF.Reglas.ModoTexto = pModo
  PUT(SELF.Reglas)


SDAspectoClass.SetPicture PROCEDURE(LONG pRegla, STRING pPattern)
  CODE
  GET(SELF.Reglas, pRegla)
  IF ERRORCODE() THEN RETURN.
  SELF.Reglas.Picture = CLIP(pPattern)
  PUT(SELF.Reglas)


SDAspectoClass.SetAccion PROCEDURE(LONG pRegla, LONG pAccion, LONG pValor)
  CODE
  GET(SELF.Reglas, pRegla)
  IF ERRORCODE() THEN RETURN.
  CASE pAccion
  OF sdAct:Color
    SELF.Reglas.Background = pValor
  OF sdAct:FontColor
    SELF.Reglas.FontColor = pValor
  OF sdAct:FontStyle
    SELF.Reglas.FontStyle = pValor
  OF sdAct:Flat
    SELF.Reglas.Flat = pValor
  ELSE
    RETURN
  END
  SELF.Reglas.Acciones = BOR(SELF.Reglas.Acciones, pAccion)
  PUT(SELF.Reglas)


SDAspectoClass.SetTip PROCEDURE(LONG pRegla, STRING pTip)
  CODE
  GET(SELF.Reglas, pRegla)
  IF ERRORCODE() THEN RETURN.
  SELF.Reglas.Tip      = pTip
  SELF.Reglas.Acciones = BOR(SELF.Reglas.Acciones, sdAct:Tip)
  PUT(SELF.Reglas)


SDAspectoClass.SetPuntero PROCEDURE(LONG pRegla, STRING pCursor)
  CODE
  GET(SELF.Reglas, pRegla)
  IF ERRORCODE() THEN RETURN.
  SELF.Reglas.Cursor   = pCursor
  SELF.Reglas.Acciones = BOR(SELF.Reglas.Acciones, sdAct:Cursor)
  PUT(SELF.Reglas)


SDAspectoClass.SetCortar PROCEDURE(LONG pRegla, BYTE pCortar)
  CODE
  !-- Cortar=1 convierte la cascada en semantica IF/ELSIF: el primer match
  !-- gana y las reglas siguientes no se evaluan para ese control.
  GET(SELF.Reglas, pRegla)
  IF ERRORCODE() THEN RETURN.
  SELF.Reglas.Cortar = pCortar
  PUT(SELF.Reglas)

!-----------------------------------------------------------------------------!
!  Aplicacion
!-----------------------------------------------------------------------------!
SDAspectoClass.ApplyToWindow PROCEDURE()
lFeq        SIGNED
lHayReglas  BYTE
lPixels     BYTE
lHandle     LONG
  CODE
  IF SELF.Deshabilitado THEN RETURN.

  !-- Toda la pasada bajo lock. Cubre a ApplyToControl, Matches y ApplyRule,
  !-- que iteran SELF.Reglas y cuelgan de aca. Serializa la apertura de
  !-- ventanas entre threads, que son milisegundos, y a cambio ningun thread
  !-- puede encontrarse la queue modificada a mitad de recorrido.
  !-- Es seguro tener el lock tomado mientras se hace SETFONT/SETPOSITION:
  !-- son operaciones sobre la ventana del PROPIO thread, no esperan a nadie.
  !-- Lo que no se puede es tener un MESSAGE adentro (ver Diagnosticar).
  SELF.Bloquear()

  lHayReglas = 0
  IF NOT SELF.Reglas &= NULL
    IF RECORDS(SELF.Reglas) THEN lHayReglas = 1.
  END
  !-- No hay corte temprano: puede no haber reglas ni tipografia y aun asi
  !-- corresponder aplicar los ajustes fijos (alto minimo, color por tipo).

  !-- Si el estado que hay en el thread es de OTRA ventana, descartarlo.
  !-- Ver el comentario de SDWinHandle: sin esto un form llamado desde un
  !-- browse hereda la geometria del browse, porque comparten thread y los
  !-- FEQ se repiten.
  lHandle = 0{PROP:Handle}
  IF SDWinHandle <> lHandle
    SELF.ResetWindow()
    SDWinHandle = lHandle
  END

  !-- Recien ACA se congela, despues del ResetWindow de arriba: ResetWindow es
  !-- ademas la red de seguridad que resetea el contador de congelado, asi que
  !-- no puede correr dentro de una region congelada.
  !-- Todo lo que sigue mueve, redimensiona y pinta controles de a uno. Sin
  !-- congelar, Windows repinta despues de cada operacion y se ve el proceso.
  SELF.CongelarPintura()

  !-- La geometria se guarda y se restaura en DIALOG UNITS, no en pixeles.
  !-- El dialog unit se define en funcion de la fuente de la ventana: si se
  !-- cambia la fuente y se reescriben los MISMOS numeros, la ventana se
  !-- reescala sola. No hay que calcular ningun factor.
  lPixels = 0{PROP:Pixels}
  0{PROP:Pixels} = FALSE

  !-- 1) Snapshot ANTES de tocar nada. Solo se captura la primera vez por
  !--    ventana; en las reaplicaciones se reusa, que es lo que hace que
  !--    volver a aplicar no acumule desplazamientos.
  SELF.SnapshotControl(0)
  lFeq = 0
  LOOP
    lFeq = 0{PROP:NextField, lFeq}
    IF NOT lFeq THEN BREAK.
    SELF.SnapshotControl(lFeq)
  END

  !-- 2) Tipografia
  IF SELF.FuenteActiva
    SELF.ResolverFuente()
    IF SELF.FuenteAVentana
      SELF.AplicarFuenteA(0)
    END
    IF SELF.FuenteAControles
      lFeq = 0
      LOOP
        lFeq = 0{PROP:NextField, lFeq}
        IF NOT lFeq THEN BREAK.
        IF NOT SELF.DebeSaltar(lFeq)
          SELF.AplicarFuenteA(lFeq)
        END
      END
    END

    !-- 3) Forzar a Clarion a recalcular el tamano del dialog unit. Sin esto
    !--    la unidad sigue siendo la de la fuente vieja y todo el rescalado
    !--    queda en nada. Es exactamente el paso que me faltaba.
    IF SELF.RescalarActivo
      SELF.RefrescarPixels()
      SELF.RestaurarGeometria()
      SELF.CentrarVentana()
    END
  END

  !-- 4) Ajustes fijos (alto minimo, color base por tipo) y despues las reglas.
  !--    En ese orden: lo fijo es la capa de abajo y una regla lo puede pisar.
  lFeq = 0
  LOOP
    lFeq = 0{PROP:NextField, lFeq}
    IF NOT lFeq THEN BREAK.
    !-- Un BUTTON sin texto no se toca: son los de la toolbar. La guarda va
    !-- ACA y no dentro de ApplyToControl, para que cubra tambien los ajustes
    !-- fijos - si no, el alto minimo les deforma la barra de herramientas.
    IF lFeq{PROP:Type} = CREATE:button
      IF NOT LEN(CLIP(SELF.NormalizeText(lFeq{PROP:Text})))
        CYCLE
      END
    END
    SELF.AplicarFijos(lFeq)
    IF lHayReglas
      SELF.ApplyToControl(lFeq)
    END
  END

  0{PROP:Pixels} = lPixels
  !-- Un solo repintado, con la ventana ya en su estado final.
  SELF.DescongelarPintura()
  SELF.Liberar()


SDAspectoClass.TakeEvent PROCEDURE()
  CODE
  !-- Segunda pasada, ya con la ventana completamente armada. Reaplicar es
  !-- inofensivo: el snapshot ya esta tomado, asi que la geometria se vuelve
  !-- a calcular desde el original y los colores se reasignan al mismo valor.
  IF EVENT() = SDAspecto:EventoRefresh
    SELF.ApplyToWindow()
    IF SELF.Diagnostico
      SELF.Diagnosticar()
    END
  END


SDAspectoClass.SinBarras PROCEDURE(STRING pTexto)
lRes        STRING(512)
lI          LONG
  CODE
  !-- MESSAGE() usa la barra vertical como separador de lineas, y las listas
  !-- del motor estan delimitadas justo con eso. Sin este cambio el cartel de
  !-- diagnostico sale partido en decenas de renglones y se trunca.
  lRes = pTexto
  LOOP lI = 1 TO SIZE(lRes)
    IF lRes[lI : lI] = '|'
      lRes[lI : lI] = '/'
    END
  END
  RETURN CLIP(lRes)


SDAspectoClass.Diagnosticar PROCEDURE()
lFeq        SIGNED
lI          LONG
lTipo       STRING(20)
lTexto      STRING(80)
lQuien      STRING(160)
lIdent      STRING(120)
lLinea      STRING(500)
lNCtl       LONG
lPix        BYTE
  CODE
  !-- Vuelca TODOS los controles de la ventana a un archivo de texto: tipo,
  !-- texto/picture, estado, fondo original capturado en el snapshot, que
  !-- reglas matchean y con que color quedo. Es la tabla que hace falta para
  !-- analizar control por control.
  !--
  !-- A archivo y no a MESSAGE: el cartel se trunca, y ademas MESSAGE trata la
  !-- barra vertical como salto de linea, que es el delimitador de las listas
  !-- del motor.
  IF NOT LEN(CLIP(SDDiagName))
    SDDiagName = '.\SDAspecto_diag.txt'
  END
  IF NOT EXISTS(SDDiagName)
    CREATE(SDDiagFile)
    IF ERRORCODE() THEN RETURN.
  END
  OPEN(SDDiagFile, 12h)
  IF ERRORCODE() THEN RETURN.

  !-- Se itera SELF.Reglas y se llama a Matches: hace falta el lock. Se libera
  !-- ANTES del MESSAGE del final: un cartel modal con el lock tomado dejaria
  !-- a todos los demas threads esperando a que el operador lo cierre.
  SELF.Bloquear()

  SDD:Linea = ''
  ADD(SDDiagFile)
  SDD:Linea = '=== ' & FORMAT(TODAY(),@d17) & ' ' & FORMAT(CLOCK(),@t4) & |
              '   ventana=' & 0{PROP:Text}
  ADD(SDDiagFile)
  SDD:Linea = '    ModoRequerido=' & SELF.ModoRequerido & |
              '   Reglas=' & RECORDS(SELF.Reglas) & |
              '   FuenteActiva=' & SELF.FuenteActiva & |
              '   Rescalar=' & SELF.RescalarActivo
  ADD(SDDiagFile)
  !-- Datos del centrado: posicion/tamano original capturado en el snapshot
  !-- (en pixeles) contra la posicion/tamano actual. Si el original quedo en
  !-- cero, CentrarVentana sale sin hacer nada.
  lPix = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  SDD:Linea = '    ventana: orig x=' & SDWinGeo.OrigWinX & ' y=' & SDWinGeo.OrigWinY & |
              ' w=' & SDWinGeo.OrigWinW & ' h=' & SDWinGeo.OrigWinH & |
              '   actual x=' & 0{PROP:Xpos} & ' y=' & 0{PROP:Ypos} & |
              ' w=' & 0{PROP:Width} & ' h=' & 0{PROP:Height} & |
              '   recentrar=' & SELF.RecentrarVentana & |
              ' rescVent=' & SELF.RescalarVentana & |
              ' max=' & 0{PROP:Maximize}
  0{PROP:Pixels} = lPix
  ADD(SDDiagFile)

  !-- Reglas tal como quedaron EN MEMORIA. Sirve para separar "el INI esta
  !-- mal" de "el INI esta bien pero se cargo mal".
  SDD:Linea = '    --- reglas en memoria ---'
  ADD(SDDiagFile)
  LOOP lI = 1 TO RECORDS(SELF.Reglas)
    GET(SELF.Reglas, lI)
    IF ERRORCODE() THEN CYCLE.
    SDD:Linea = '    [' & lI & '] ' & CLIP(SELF.Reglas.Nombre) & |
                '  act=' & SELF.Reglas.Activa & |
                '  req=' & SELF.Reglas.TestReq & |
                '  ro='  & SELF.Reglas.TestReadOnly & |
                '  dis=' & SELF.Reglas.TestDisable & |
                '  acc=' & SELF.Reglas.Acciones & |
                '  col=' & SELF.Reglas.Background & |
                '  cor=' & SELF.Reglas.Cortar & |
                '  tipos=' & SELF.SinBarras(SELF.Reglas.Tipos) & |
                '  txt='  & SELF.SinBarras(SELF.Reglas.Texto)
    ADD(SDDiagFile)
  END

  SDD:Linea = '    feq  tipo       texto/picture        req ro dis trn  fondoOrig    colorFinal  reglas'
  ADD(SDDiagFile)

  lNCtl = 0
  lFeq  = 0
  LOOP
    lFeq = 0{PROP:NextField, lFeq}
    IF NOT lFeq THEN BREAK.
    lNCtl += 1
    lTipo = SELF.TipoToNombre(lFeq{PROP:Type})
    IF NOT LEN(CLIP(lTipo)) THEN CYCLE.
    lTexto = SELF.SinBarras(CLIP(lFeq{PROP:Text}))

    !-- todas las reglas que matchean, en orden
    lQuien = ''
    LOOP lI = 1 TO RECORDS(SELF.Reglas)
      GET(SELF.Reglas, lI)
      IF ERRORCODE() THEN CYCLE.
      IF NOT SELF.Reglas.Activa THEN CYCLE.
      IF SELF.Matches(lFeq, lI)
        IF LEN(CLIP(lQuien))
          lQuien = CLIP(lQuien) & '+'
        END
        lQuien = CLIP(lQuien) & CLIP(SELF.Reglas.Nombre)
        IF SELF.Reglas.Cortar
          lQuien = CLIP(lQuien) & '(corta)'
          BREAK
        END
      END
    END
    IF NOT LEN(CLIP(lQuien))
      lQuien = '-'
    END

    lLinea = '    ' & FORMAT(lFeq,@n-5) & ' ' & |
             SUB(lTipo & '          ', 1, 10) & ' ' & |
             SUB('[' & CLIP(lTexto) & ']                     ', 1, 21) & ' ' & |
             FORMAT(lFeq{PROP:Req},@n-3) & FORMAT(lFeq{PROP:ReadOnly},@n-3) & |
             FORMAT(lFeq{PROP:Disable},@n-3) & FORMAT(lFeq{PROP:Trn},@n-3) & '  ' & |
             FORMAT(SELF.FondoOriginal(lFeq),@n-12) & ' ' & |
             FORMAT(SELF.FondoActual(lFeq),@n-12) & '  ' & CLIP(lQuien)
    !-- Clarion no expone el nombre de diseno del control en runtime.
    !-- PROP:Msg es lo mas cercano: las apps ABC lo llenan desde el
    !-- diccionario. Si viene vacio, se cae al TIP.
    lIdent = SELF.SinBarras(CLIP(lFeq{PROP:Msg}))
    IF NOT LEN(CLIP(lIdent))
      lIdent = SELF.SinBarras(CLIP(lFeq{PROP:Tip}))
    END
    IF LEN(CLIP(lIdent))
      lLinea = CLIP(lLinea) & '   msg=[' & CLIP(lIdent) & ']'
    END
    SDD:Linea = lLinea
    ADD(SDDiagFile)
  END

  SDD:Linea = '    total de controles: ' & lNCtl
  ADD(SDDiagFile)
  CLOSE(SDDiagFile)
  SELF.Liberar()

  MESSAGE('Diagnostico agregado a:||' & CLIP(SDDiagName) & |
          '||Controles: ' & lNCtl & '    Reglas: ' & RECORDS(SELF.Reglas), |
          'SDAspecto', ICON:Asterisk)


SDAspectoClass.FondoOriginal PROCEDURE(SIGNED pFeq)
  CODE
  !-- El fondo que el control traia del disenador, del snapshot. Es lo que mira
  !-- TieneFondoPropio para decidir si un campo es obligatorio.
  IF NOT RECORDS(SDWinState) THEN RETURN 0.
  CLEAR(SDWinState)
  SDWinState.Feq = pFeq
  GET(SDWinState, SDWinState.Feq)
  IF ERRORCODE() THEN RETURN 0.
  RETURN SDWinState.OrigBackground


SDAspectoClass.CentrarVentana PROCEDURE()
lPixels     BYTE
lW          LONG
lH          LONG
lX          LONG
lY          LONG
  CODE
  !-- Al crecer la ventana, su esquina superior izquierda queda donde estaba,
  !-- asi que visualmente se corre hacia abajo y a la derecha. Se compensa
  !-- moviendola la MITAD de lo que crecio: el centro queda donde estaba, y
  !-- una ventana que estaba centrada en pantalla sigue centrada.
  IF NOT SELF.RecentrarVentana THEN RETURN.
  IF NOT SELF.RescalarVentana THEN RETURN.
  IF 0{PROP:Maximize} THEN RETURN.
  IF SDWinGeo.OrigWinW <= 0 THEN RETURN.

  lPixels = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  lW = 0{PROP:Width}
  lH = 0{PROP:Height}
  lX = SDWinGeo.OrigWinX + (SDWinGeo.OrigWinW - lW) / 2
  lY = SDWinGeo.OrigWinY + (SDWinGeo.OrigWinH - lH) / 2
  !-- No dejarla salir por arriba ni por la izquierda: desde ahi no se puede
  !-- arrastrar de vuelta.
  IF lX < 0 THEN lX = 0.
  IF lY < 0 THEN lY = 0.
  SETPOSITION(0, lX, lY)
  IF NOT lPixels
    0{PROP:Pixels} = 0
  END


!-----------------------------------------------------------------------------!
!  Congelado del repintado.
!
!  El sintoma que esto resuelve: en una ventana con muchos controles se ve como
!  cada uno se mueve y se pinta de a uno, y en el medio asoma el fondo sin
!  borrar (se ve negro). Windows repinta despues de CADA SETPOSITION, SETFONT y
!  cambio de color; con cientos de controles son cientos de repintados.
!
!  WM_SETREDRAW=0 apaga el redibujado de la ventana y sus hijos. Se hacen todos
!  los cambios sin que se dibuje nada, y al final se prende y se repinta UNA
!  sola vez. Es la solucion estandar de Windows para esto.
!-----------------------------------------------------------------------------!
SDAspectoClass.CongelarPintura PROCEDURE()
  CODE
  !-- APAGADO POR DEFECTO. En 3.02 esto se aplicaba siempre y rompio la ventana
  !-- principal de una aplicacion MDI: no arrancaba maximizada y se cerraba al
  !-- maximizarla. El frame MDI no se puede congelar durante su Init - el
  !-- runtime todavia esta armando el cliente MDI, la toolbar y el estado de
  !-- maximizado, y apagarle el redibujado en el medio le deja el estado
  !-- inconsistente.
  IF NOT SELF.CongelarActivo THEN RETURN.

  !-- Aun encendido, SOLO ventanas MDI hijas. El frame nunca.
  IF NOT 0{PROP:MDI} THEN RETURN.

  SDWinGeo.CongelaDepth += 1
  IF SDWinGeo.CongelaDepth > 1 THEN RETURN.      !-- ya estaba congelada
  SDWinGeo.CongelaHwnd = 0{PROP:Handle}
  IF NOT SDWinGeo.CongelaHwnd
    SDWinGeo.CongelaDepth = 0
    RETURN
  END
  SDA:SendMessage(SDWinGeo.CongelaHwnd, WM_SETREDRAW, 0, 0)


SDAspectoClass.DescongelarPintura PROCEDURE()
  CODE
  IF SDWinGeo.CongelaDepth <= 0
    SDWinGeo.CongelaDepth = 0
    RETURN
  END
  SDWinGeo.CongelaDepth -= 1
  IF SDWinGeo.CongelaDepth THEN RETURN.          !-- queda un nivel de afuera
  IF NOT SDWinGeo.CongelaHwnd THEN RETURN.
  SDA:SendMessage(SDWinGeo.CongelaHwnd, WM_SETREDRAW, 1, 0)
  !-- Prender WM_SETREDRAW no repinta solo: hay que invalidar explicitamente.
  !-- Sin RDW_ALLCHILDREN los controles quedan en blanco hasta que algo los
  !-- toque.
  SDA:RedrawWindow(SDWinGeo.CongelaHwnd, 0, 0, RDW_TODO)
  SDWinGeo.CongelaHwnd = 0


SDAspectoClass.RefrescarPixels PROCEDURE()
lPixels     BYTE
  CODE
  !-- Alternar el modo pixel obliga al runtime a recalcular el tamano de la
  !-- unidad de dialogo con la fuente nueva. Clarion NO lo hace solo al
  !-- cambiar PROP:FontName / PROP:FontSize.
  lPixels = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  0{PROP:Pixels} = 0
  IF lPixels
    0{PROP:Pixels} = 1
  END


SDAspectoClass.DebeSaltar PROCEDURE(SIGNED pFeq)
  CODE
  IF pFeq = 0 THEN RETURN 0.
  CASE pFeq{PROP:Type}
  OF CREATE:sublist                     !-- lista interna de un DROP
    RETURN 1
  OF CREATE:DropButton                  !-- boton de despliegue de un COMBO
    RETURN 1
  OF CREATE:menu
  OROF CREATE:item
  OROF CREATE:menubar
    IF SELF.PreservarMenu THEN RETURN 1.
  OF CREATE:toolbar
    IF SELF.PreservarToolbar THEN RETURN 1.
  END
  IF SELF.PreservarToolbar
    IF pFeq{PROP:InToolbar} THEN RETURN 1.
  END
  RETURN 0


SDAspectoClass.RestaurarGeometria PROCEDURE()
lI          LONG
lJ          LONG
lFeq        SIGNED
lTipo       LONG
lNoW        BYTE
lNoH        BYTE
  CODE
  !-- Se recorre el SNAPSHOT y se reescriben los valores originales en dialog
  !-- units. Como la unidad ya vale distinto (fuente nueva + RefrescarPixels),
  !-- el mismo numero produce una posicion y un tamano mayores o menores.
  !--
  !-- ORDEN INVERSO a proposito: el snapshot se armo con la ventana primero,
  !-- asi que al reves los controles se acomodan antes y la ventana queda para
  !-- el final. Redimensionar la ventana primero descoloca todo lo de adentro.
  LOOP lI = RECORDS(SDWinState) TO 1 BY -1
    GET(SDWinState, lI)
    IF ERRORCODE() THEN CYCLE.
    IF NOT SDWinState.Snapshot THEN CYCLE.
    IF SDWinState.Omitido THEN CYCLE.
    IF SDWinState.Saltar THEN CYCLE.

    lFeq = SDWinState.Feq
    IF lFeq = 0
      IF NOT SELF.RescalarVentana THEN CYCLE.
      !-- Una ventana maximizada no se toca.
      IF 0{PROP:Maximize} THEN CYCLE.
      !-- Restaurar los minimos ANTES de redimensionar, o el minimo viejo
      !-- puede impedir que la ventana crezca o achique.
      !-- OJO: si la ventana tiene el resizer de ABC, estas dos propiedades no
      !-- son nuestras. Resizer.Init las fija con Resize:SetMinSize, y ABC puede
      !-- fijar ademas MaxWidth/MaxHeight. Al pisarlas con los valores del
      !-- snapshot -que estan en dialog units de la fuente VIEJA- el minimo
      !-- puede terminar por encima del maximo, y ahi la ventana no se deja
      !-- redimensionar. Con RespetarResizer no se tocan.
      IF NOT SELF.RespetarResizer
        IF SDWinGeo.OrigMinWidth > 0
          0{PROP:MinWidth} = SDWinGeo.OrigMinWidth
        END
        IF SDWinGeo.OrigMinHeight > 0
          0{PROP:MinHeight} = SDWinGeo.OrigMinHeight
        END
      END
      !-- xpos/ypos de la ventana NO se tocan: SETFONT ya la reposiciono sola,
      !-- porque sus coordenadas son relativas a la unidad de dialogo.
      !-- Mismo criterio que con los controles: una dimension no positiva no se
      !-- escribe nunca, o la ventana se colapsa.
      IF SDWinState.OrigWidth > 0 AND SDWinState.OrigHeight > 0
        SETPOSITION(0, , , SDWinState.OrigWidth, SDWinState.OrigHeight)
      END
      CYCLE
    END

    !-- Un control declarado sin ancho o sin alto explicito se dimensiona
    !-- solo segun su contenido: fijarle tamano lo deforma.
    lNoW = lFeq{PROP:NoWidth}
    lNoH = lFeq{PROP:NoHeight}

    !-- Y NUNCA escribir una dimension que no sea positiva.
    !-- Un IMAGE toma su tamano del archivo, no del disenador, y PROP:NoWidth
    !-- no lo declara: si el snapshot corrio antes de que la imagen estuviera
    !-- resuelta, quedo en cero. Escribir ese cero deja el control con tamano
    !-- nulo. El sintoma es que "el template oculta la imagen", pero no la
    !-- oculta: la redimensiona a nada.
    !-- Se reusa la misma logica de No-ancho / No-alto, que ya sabe dejar la
    !-- dimension sin tocar.
    IF SDWinState.OrigWidth  <= 0 THEN lNoW = 1.
    IF SDWinState.OrigHeight <= 0 THEN lNoH = 1.

    IF lNoW AND lNoH
      SETPOSITION(lFeq, SDWinState.OrigXpos, SDWinState.OrigYpos)
    ELSIF lNoW
      SETPOSITION(lFeq, SDWinState.OrigXpos, SDWinState.OrigYpos, , SDWinState.OrigHeight)
    ELSIF lNoH
      SETPOSITION(lFeq, SDWinState.OrigXpos, SDWinState.OrigYpos, SDWinState.OrigWidth)
    ELSE
      SETPOSITION(lFeq, SDWinState.OrigXpos, SDWinState.OrigYpos, |
                  SDWinState.OrigWidth, SDWinState.OrigHeight)
    END

    IF SDWinState.OrigAngulo
      lFeq{PROP:Angle} = SDWinState.OrigAngulo
    END

    !-- LIST y COMBO: alto de linea y anchos de columna. Los anchos son
    !-- propiedades indexadas, no hay que tocar PROP:Format.
    lTipo = lFeq{PROP:Type}
    IF lTipo = CREATE:list OR lTipo = CREATE:combo
      IF SDWinState.OrigLineHeight > 0
        lFeq{PROP:LineHeight} = SDWinState.OrigLineHeight
      END
      IF NOT SDWinState.Columnas &= NULL
        LOOP lJ = 1 TO RECORDS(SDWinState.Columnas)
          GET(SDWinState.Columnas, lJ)
          IF ERRORCODE() THEN CYCLE.
          lFeq{PROPLIST:width, lJ} = SDWinState.Columnas.Ancho
          IF SDWinState.Columnas.Grupo
            lFeq{PROPLIST:group + PROPLIST:width, lJ} = SDWinState.Columnas.AnchoGrupo
          END
        END
      END
    END
  END


SDAspectoClass.PintarFondo PROCEDURE(SIGNED pFeq, LONG pColor)
lProp       LONG
  CODE
  !-- Una regla tiene UN solo color. El destino lo decide el tipo de control:
  !--    BUTTON          ->  PROP:FontColor   (la LETRA, no el fondo)
  !--    PANEL, REGION   ->  PROP:Fill
  !--    el resto        ->  PROP:Color
  !--
  !-- El BUTTON va a la letra a proposito: asignarle color de FONDO obliga al
  !-- runtime a sacarlo del modo themed para poder pintarlo, y ahi pierde la
  !-- forma nativa (esquinas redondeadas, hover). El color de letra no dispara
  !-- eso. PANEL y REGION solo responden a PROP:Fill, verificado.
  !--
  !-- Todo el pintado pasa por aca, tanto los ajustes fijos como las reglas,
  !-- para que la decision quede en un solo lugar.
  CASE pFeq{PROP:Type}
  OF CREATE:button
    lProp = PROP:FontColor
  OF CREATE:panel
  OROF CREATE:region
  OROF CREATE:group
    lProp = PROP:Fill
  ELSE
    lProp = PROP:Color
  END
  !-- Asignar solo si cambia: reescribir una propiedad con el valor que ya
  !-- tiene no es un no-op en Clarion.
  IF pFeq{lProp} <> pColor
    pFeq{lProp} = pColor
  END


SDAspectoClass.FondoActual PROCEDURE(SIGNED pFeq)
  CODE
  !-- Lectura simetrica de PintarFondo, para el diagnostico.
  CASE pFeq{PROP:Type}
  OF CREATE:button
    RETURN pFeq{PROP:FontColor}
  OF CREATE:panel
  OROF CREATE:region
  OROF CREATE:group
    RETURN pFeq{PROP:Fill}
  END
  RETURN pFeq{PROP:Color}


SDAspectoClass.AplicarFijos PROCEDURE(SIGNED pFeq)
lTipo       LONG
lColor      LONG
  CODE
  !-- Ajustes que NO son condicionales: se aplican siempre, como la
  !-- tipografia. Corren ANTES que las reglas, asi una regla puede pisarlos
  !-- en un control puntual.
  lTipo  = pFeq{PROP:Type}
  lColor = -1
  CASE lTipo
  OF CREATE:tab
    !-- OJO con el VALOR que se le ponga: el borde de un GROUP se dibuja en un
    !-- gris de alrededor de D9D9D9. Si el TAB queda de ese mismo tono, los
    !-- GROUP que tenga adentro pierden visualmente el borde - esta dibujado,
    !-- pero no se distingue del fondo. El default de SDAspecto era D8D8D8 y
    !-- colisionaba justo ahi.
    lColor = SELF.ColorTab
  OF CREATE:sheet
    lColor = SELF.ColorSheet
  OF CREATE:panel
    lColor = SELF.ColorPanel
  OF CREATE:region
    lColor = SELF.ColorRegion
  OF CREATE:list
    lColor = SELF.ColorList
  OF CREATE:combo
  OROF CREATE:dropcombo
  OROF CREATE:droplist
    lColor = SELF.ColorCombo
  OF CREATE:option
    lColor = SELF.ColorOption
  OF CREATE:spin
    lColor = SELF.ColorSpin
  OF CREATE:text
    lColor = SELF.ColorText
  END
  !-- -1 (COLOR:NONE) y 0 se tratan como "no aplicar". El 0 tambien, a
  !-- proposito: es lo que devuelve un prompt COLOR sin DEFAULT o una clave
  !-- ausente del INI, y un fondo negro no es nunca una eleccion deliberada
  !-- para un control. Si alguna vez hace falta negro de verdad, 010101h.
  IF lColor <> -1 AND lColor <> 0
    SELF.PintarFondo(pFeq, lColor)
  END

  !-- Alto minimo. Se compara contra el alto ACTUAL, no el snapshot: si hubo
  !-- rescalado, el piso va sobre el alto ya rescalado. Nunca suma, solo sube
  !-- al piso, asi que reaplicar es inofensivo.
  IF SELF.AltoMinimo > 0
    CASE lTipo
    OF CREATE:entry
    OROF CREATE:spin
    OROF CREATE:check
    OROF CREATE:combo
    OROF CREATE:dropcombo
    OROF CREATE:droplist
    OROF CREATE:list
    OROF CREATE:button
      IF pFeq{PROP:Height} < SELF.AltoMinimo
        pFeq{PROP:Height} = SELF.AltoMinimo
      END
    END
  END


SDAspectoClass.ResolverFuente PROCEDURE()
  CODE
  !-- Fuente actual de la ventana. Es la referencia contra la que se compara
  !-- cada control para decidir si su fuente es "la heredada" o una propia.
  GETFONT(0, SDWinGeo.FteVieja.Nombre, SDWinGeo.FteVieja.Tamano, SDWinGeo.FteVieja.Color, |
             SDWinGeo.FteVieja.Estilo, SDWinGeo.FteVieja.Charset)

  !-- La fuente nueva es la configurada, y donde no se configuro nada
  !-- (-1 o cadena vacia) se conserva la vieja.
  IF LEN(CLIP(SELF.FuenteNombre))
    SDWinGeo.FteNueva.Nombre = SELF.FuenteNombre
  ELSE
    SDWinGeo.FteNueva.Nombre = SDWinGeo.FteVieja.Nombre
  END
  SDWinGeo.FteNueva.Tamano  = CHOOSE(SELF.FuenteTamano  >  0, SELF.FuenteTamano,  SDWinGeo.FteVieja.Tamano)
  SDWinGeo.FteNueva.Color   = CHOOSE(SELF.FuenteColor  <> -1, SELF.FuenteColor,   SDWinGeo.FteVieja.Color)
  SDWinGeo.FteNueva.Estilo  = CHOOSE(SELF.FuenteEstilo >=  0, SELF.FuenteEstilo,  SDWinGeo.FteVieja.Estilo)
  SDWinGeo.FteNueva.Charset = CHOOSE(SELF.FuenteCharset>=  0, SELF.FuenteCharset, SDWinGeo.FteVieja.Charset)


SDAspectoClass.AplicarFuenteA PROCEDURE(SIGNED pFeq)
lNom        STRING(64)
lTam        LONG
lCol        LONG
lEst        LONG
lChr        LONG
lTipo       LONG
lX          LONG
lY          LONG
lHayCambio  BYTE
  CODE
  lTipo = 0
  IF pFeq <> 0
    lTipo = pFeq{PROP:Type}
  END
  !-- SETFONT rompe los controles RTF.
  IF lTipo = CREATE:rtf THEN RETURN.

  !-- Se parte de la fuente ACTUAL del control y solo se reemplaza atributo
  !-- por atributo lo que coincide con la fuente vieja de la ventana. Un
  !-- control al que le pusiste otra tipografia en el disenador la conserva.
  lNom = pFeq{PROP:FontName}
  lTam = pFeq{PROP:FontSize}
  lCol = pFeq{PROP:FontColor}
  lEst = pFeq{PROP:FontStyle}
  lChr = pFeq{PROP:FontCharSet}

  IF lNom = SDWinGeo.FteVieja.Nombre  THEN lNom = SDWinGeo.FteNueva.Nombre.
  IF lTam = SDWinGeo.FteVieja.Tamano  THEN lTam = SDWinGeo.FteNueva.Tamano.
  IF lCol = SDWinGeo.FteVieja.Color   THEN lCol = SDWinGeo.FteNueva.Color.
  IF lEst = SDWinGeo.FteVieja.Estilo  THEN lEst = SDWinGeo.FteNueva.Estilo.
  IF lChr = SDWinGeo.FteVieja.Charset THEN lChr = SDWinGeo.FteNueva.Charset.

  CASE lTipo
  OF CREATE:menu
  OROF CREATE:menubar
  OROF CREATE:item
    !-- SETFONT no funciona sobre menus: hay que ir por propiedades, y solo
    !-- las que realmente cambian.
    IF pFeq{PROP:FontName} <> lNom
      pFeq{PROP:FontName} = lNom
    END
    IF pFeq{PROP:FontSize} <> lTam
      pFeq{PROP:FontSize} = lTam
    END
    IF pFeq{PROP:FontColor} <> lCol
      pFeq{PROP:FontColor} = lCol
    END
    IF pFeq{PROP:FontStyle} <> lEst
      pFeq{PROP:FontStyle} = lEst
    END
    IF pFeq{PROP:FontCharSet} <> lChr
      pFeq{PROP:FontCharSet} = lChr
    END
  ELSE
    !-- CENTINELAS DE "NO TOCAR" -----------------------------------------------
    !-- Hasta la 3.06 esto le pasaba SIEMPRE a SETFONT un color y un estilo
    !-- explicitos, aunque fueran los que el control ya tenia. Visualmente daba
    !-- lo mismo, pero para Windows es una ASIGNACION de color, y eso saca al
    !-- control del modo themed. El sintoma: un GROUP pierde el marco del BOXED,
    !-- y solo volvia desactivando los temas en el manifiesto.
    !--
    !-- Es el mismo error que ya teniamos resuelto en PintarFondo -reescribir una
    !-- propiedad con el valor que ya tiene NO es un no-op en Clarion- pero que
    !-- nunca habiamos aplicado aca.
    !--
    !-- El prototipo lo contempla:
    !--   SETFONT(feq, <typeface>, size=0, color=COLOR:None, style=-1, ...)
    !-- COLOR:None en el color y -1 en el estilo significan "no lo toques".
    !--
    !-- Asi que cada atributo que NO va a cambiar se reemplaza por su centinela.
    !-- Cubre los dos casos: que no haya color configurado, y que el control
    !-- tenga una tipografia propia del disenador que hay que respetar.
    !--
    !-- El charset queda como estaba a proposito: su default es CHARSET:Default,
    !-- que ASIGNA el charset por defecto en vez de significar "no tocar", asi
    !-- que no hay centinela que usar.
    !--
    !-- OJO: la rama de los menus de arriba NO pasa por aca, y tiene que seguir
    !-- asi. Esa compara con IF <> antes de asignar; con un centinela adentro
    !-- terminaria escribiendo -1 como color real.
    lHayCambio = 0
    IF lNom <> pFeq{PROP:FontName} OR lTam <> pFeq{PROP:FontSize} OR |
       lCol <> pFeq{PROP:FontColor} OR lEst <> pFeq{PROP:FontStyle} OR |
       lChr <> pFeq{PROP:FontCharSet}
      lHayCambio = 1
    END
    !-- La sustitucion va DESPUES de decidir si hay cambio: si fuera antes, el
    !-- centinela no coincidiria con el valor actual y pareceria un cambio.
    IF lCol = pFeq{PROP:FontColor} THEN lCol = COLOR:None.
    IF lEst = pFeq{PROP:FontStyle} THEN lEst = -1.

    IF pFeq = 0
      !-- SETFONT sobre la ventana le corre xpos/ypos, porque son relativos
      !-- a la unidad de dialogo, que es justo lo que acaba de cambiar.
      !-- Hay que preservarlos a mano.
      !--
      !-- PERO NO SI ESTA MAXIMIZADA. En una ventana maximizada la posicion la
      !-- administra Windows, y un SETPOSITION la deja en un estado hibrido:
      !-- ni maximizada de verdad ni restaurada. El sintoma es que una ventana
      !-- que arranca con PROP:Maximize=1 en el Init queda rota, mientras que
      !-- la misma ventana abierta normal y maximizada despues a mano anda bien
      !-- (porque ahi el SETPOSITION corrio cuando todavia no estaba maximizada).
      !-- RestaurarGeometria y CentrarVentana ya tenian esta guarda; este era el
      !-- unico SETPOSITION sobre la ventana que habia quedado sin ella.
      IF 0{PROP:Maximize}
        SETFONT(0, lNom, lTam, lCol, lEst, lChr)
      ELSE
        GETPOSITION(0, lX, lY)
        SETFONT(0, lNom, lTam, lCol, lEst, lChr)
        SETPOSITION(0, lX, lY)
      END
    ELSE
      !-- Solo si algo cambio de verdad. Un SETFONT redundante repinta el
      !-- control y puede alterarle el aspecto.
      IF lHayCambio
        SETFONT(pFeq, lNom, lTam, lCol, lEst, lChr)
      END
    END
  END

  !-- Reasignar el angulo fuerza el redibujado del texto rotado.
  IF pFeq <> 0
    IF pFeq{PROP:Angle}
      pFeq{PROP:Angle} = pFeq{PROP:Angle}
    END
  END


SDAspectoClass.SnapshotControl PROCEDURE(SIGNED pFeq)
lTipo       LONG
lCols       LONG
lI          LONG
  CODE
  IF RECORDS(SDWinState)
    CLEAR(SDWinState)
    SDWinState.Feq = pFeq
    GET(SDWinState, SDWinState.Feq)
    IF NOT ERRORCODE() AND SDWinState.Snapshot
      RETURN                          !-- ya estaba capturado
    END
  END
  CLEAR(SDWinState)
  SDWinState.Feq            = pFeq
  SDWinState.Snapshot       = 1
  SDWinState.Saltar         = SELF.DebeSaltar(pFeq)
  SDWinState.OrigBackground = pFeq{PROP:Color}
  SDWinState.Columnas      &= NULL

  !-- GETPOSITION lee en el sistema de unidades vigente. ApplyToWindow ya
  !-- puso PROP:Pixels en 0, asi que esto queda en dialog units.
  GETPOSITION(pFeq, SDWinState.OrigXpos, SDWinState.OrigYpos, |
              SDWinState.OrigWidth, SDWinState.OrigHeight)

  IF pFeq <> 0
    SDWinState.OrigAngulo = pFeq{PROP:Angle}
    lTipo = pFeq{PROP:Type}
    IF lTipo = CREATE:list OR lTipo = CREATE:combo
      SDWinState.OrigLineHeight = pFeq{PROP:LineHeight}
      SDWinState.Columnas &= NEW SDColWQType
      IF NOT SDWinState.Columnas &= NULL
        lCols = pFeq{PROPLIST:Exists, 0}
        LOOP lI = 1 TO lCols
          CLEAR(SDWinState.Columnas)
          SDWinState.Columnas.Ancho      = pFeq{PROPLIST:width, lI}
          SDWinState.Columnas.Grupo      = pFeq{PROPLIST:GroupNo, lI}
          SDWinState.Columnas.AnchoGrupo = pFeq{PROPLIST:group + PROPLIST:width, lI}
          ADD(SDWinState.Columnas)
        END
      END
    END
  ELSE
    SDWinGeo.OrigClientH   = 0{PROP:ClientHeight}
    SDWinGeo.OrigMinWidth  = 0{PROP:MinWidth}
    SDWinGeo.OrigMinHeight = 0{PROP:MinHeight}
    !-- Posicion y tamano en PIXELES, para poder recentrar despues comparando
    !-- contra el tamano final. En dialog units no serviria: la unidad es
    !-- justamente lo que va a cambiar.
    0{PROP:Pixels} = 1
    GETPOSITION(0, SDWinGeo.OrigWinX, SDWinGeo.OrigWinY, SDWinGeo.OrigWinW, SDWinGeo.OrigWinH)
    0{PROP:Pixels} = 0
    !-- Si arranca maximizada, lo que acabamos de leer es el tamano de la
    !-- PANTALLA, no el de diseno. Guardarlo como "original" es veneno: si mas
    !-- tarde se restaura la ventana y se vuelve a aplicar, CentrarVentana
    !-- calcularia el desplazamiento contra el tamano de la pantalla y la
    !-- mandaria a cualquier lado. Se anula el ancho, que es justo la condicion
    !-- de corte que CentrarVentana ya tiene.
    IF 0{PROP:Maximize}
      SDWinGeo.OrigWinW = 0
    END
  END

  !-- ADD CON CLAVE, no ADD suelto. La queue se consulta con
  !-- GET(SDWinState, SDWinState.Feq) desde cuatro lugares distintos, y esa
  !-- forma recorre la queue SECUENCIALMENTE salvo que este ordenada por ese
  !-- campo. Con ADD suelto quedaba desordenada: cada consulta era un barrido,
  !-- y con ~4 consultas por control sobre una queue de N entradas la apertura
  !-- de una ventana costaba del orden de N^2. Manteniendola ordenada, el GET
  !-- pasa a ser una busqueda binaria.
  !-- Efecto colateral util: RestaurarGeometria recorre al reves y necesita que
  !-- la ventana (Feq=0) quede al final. Ordenado por Feq ascendente, el 0 es el
  !-- primero, asi que al reves sigue siendo el ultimo. Y ahora esa garantia no
  !-- depende del orden en que se insertaron.
  ADD(SDWinState, SDWinState.Feq)


SDAspectoClass.TieneFondoPropio PROCEDURE(SIGNED pFeq)
  CODE
  !-- Lee el SNAPSHOT, nunca la propiedad actual: si leyera la actual, en una
  !-- segunda pasada todo control ya pintado pareceria tener fondo propio.
  !-- Ese era justamente el bug de SdTpl.TPL:14.
  IF NOT RECORDS(SDWinState) THEN RETURN 0.
  CLEAR(SDWinState)
  SDWinState.Feq = pFeq
  GET(SDWinState, SDWinState.Feq)
  IF ERRORCODE() THEN RETURN 0.
  IF NOT SDWinState.Snapshot THEN RETURN 0.
  IF SDWinState.OrigBackground = COLOR:NONE THEN RETURN 0.
  IF SDWinState.OrigBackground = 0 THEN RETURN 0.
  RETURN 1


SDAspectoClass.EsRequerido PROCEDURE(SIGNED pFeq)
  CODE
  IF BAND(SELF.ModoRequerido, sdReq:AtributoREQ)
    IF pFeq{PROP:Req} THEN RETURN 1.
  END
  IF BAND(SELF.ModoRequerido, sdReq:FondoDisenio)
    IF SELF.TieneFondoPropio(pFeq) THEN RETURN 1.
  END
  RETURN 0


SDAspectoClass.ApplyToControl PROCEDURE(SIGNED pFeq)
lI          LONG
lStop       BYTE
  CODE
  !-- control excluido explicitamente para esta ventana
  !-- (el chequeo de RECORDS evita el CLEAR+GET en el caso normal, que es
  !--  que no haya ningun control omitido)
  IF RECORDS(SDWinState)
    CLEAR(SDWinState)
    SDWinState.Feq = pFeq
    GET(SDWinState, SDWinState.Feq)
    IF NOT ERRORCODE() AND SDWinState.Omitido
      RETURN
    END
  END

  !-- (el filtro de BUTTON sin texto esta en ApplyToWindow, para que cubra
  !--  tambien los ajustes fijos y no quede duplicado)

  !-- cascada: todas las reglas que matchean aplican, la ultima gana por
  !-- propiedad. Cortar=1 corta.
  LOOP lI = 1 TO RECORDS(SELF.Reglas)
    GET(SELF.Reglas, lI)
    IF ERRORCODE() THEN CYCLE.
    IF NOT SELF.Reglas.Activa THEN CYCLE.
    IF SELF.Matches(pFeq, lI)
      SELF.ApplyRule(pFeq, lI)
      !-- ApplyRule dejo la regla lI en el buffer
      GET(SELF.Reglas, lI)
      lStop = CHOOSE(ERRORCODE() = 0, SELF.Reglas.Cortar, 0)
      IF lStop THEN BREAK.
    END
  END


SDAspectoClass.Matches PROCEDURE(SIGNED pFeq, LONG pRegla)
lNombre     STRING(20)
lTexto      STRING(256)
lLista      STRING(512)   !-- igual que Reglas.Texto, o se truncaria la lista
lItem       STRING(256)
lPos        LONG
lFin        LONG
lOk         BYTE
  CODE
  GET(SELF.Reglas, pRegla)
  IF ERRORCODE() THEN RETURN 0.

  !-- 1) tipo de control -----------------------------------------------------
  lNombre = SELF.TipoToNombre(pFeq{PROP:Type})
  IF NOT LEN(CLIP(lNombre)) THEN RETURN 0.
  IF NOT SELF.EnLista(SELF.Reglas.Tipos, lNombre) THEN RETURN 0.

  !-- 2) criterios booleanos -------------------------------------------------
  !-- Se leen propiedades que NINGUNA accion modifica, asi el motor es
  !-- idempotente sin necesidad de cachear valores originales.
  !-- "Requerido" no es solo PROP:Req: segun ModoRequerido tambien cuenta que
  !-- el control trajera un fondo propio del disenador (ver EsRequerido).
  CASE SELF.Reglas.TestReq
  OF sdTest:Si
    IF NOT SELF.EsRequerido(pFeq) THEN RETURN 0.
  OF sdTest:No
    IF SELF.EsRequerido(pFeq) THEN RETURN 0.
  END

  CASE SELF.Reglas.TestReadOnly
  OF sdTest:Si
    IF NOT pFeq{PROP:ReadOnly} THEN RETURN 0.
  OF sdTest:No
    IF pFeq{PROP:ReadOnly} THEN RETURN 0.
  END

  CASE SELF.Reglas.TestDisable
  OF sdTest:Si
    IF NOT pFeq{PROP:Disable} THEN RETURN 0.
  OF sdTest:No
    IF pFeq{PROP:Disable} THEN RETURN 0.
  END

  !-- 3) texto / picture -----------------------------------------------------
  !-- Ojo: PROP:Text es el caption en BUTTON/CHECK/OPTION/PROMPT/STRING,
  !--      pero es la PICTURE en ENTRY/SPIN. Por eso son dos criterios.
  IF LEN(CLIP(SELF.Reglas.Texto))
    lTexto = SELF.NormalizeText(pFeq{PROP:Text})
    CASE SELF.Reglas.ModoTexto
    OF sdText:Exacto
      IF NOT SELF.EnLista(SELF.Reglas.Texto, lTexto) THEN RETURN 0.
    ELSE
      !-- Contiene / Empieza: recorrer la lista item por item
      lLista = SELF.Reglas.Texto
      lOk    = 0
      lPos   = 2
      LOOP
        lFin = INSTRING('|', CLIP(lLista), 1, lPos)
        IF NOT lFin THEN BREAK.
        lItem = SUB(lLista, lPos, lFin - lPos)
        IF LEN(CLIP(lItem))
          CASE SELF.Reglas.ModoTexto
          OF sdText:Contiene
            IF INSTRING(CLIP(lItem), CLIP(lTexto), 1, 1) THEN lOk = 1.
          OF sdText:Empieza
            IF SUB(lTexto, 1, LEN(CLIP(lItem))) = CLIP(lItem) THEN lOk = 1.
          END
        END
        IF lOk THEN BREAK.
        lPos = lFin + 1
      END
      IF NOT lOk THEN RETURN 0.
    END
  END

  IF LEN(CLIP(SELF.Reglas.Picture))
    IF NOT MATCH(CLIP(pFeq{PROP:Text}), CLIP(SELF.Reglas.Picture), Match:Wild)
      RETURN 0
    END
  END

  RETURN 1


SDAspectoClass.ApplyRule PROCEDURE(SIGNED pFeq, LONG pRegla)
lColor      LONG
  CODE
  GET(SELF.Reglas, pRegla)
  IF ERRORCODE() THEN RETURN.

  !-- REGLA DE ORO: nunca reasignar una propiedad que ya tiene el valor
  !-- buscado. En Clarion reescribirla tiene efectos secundarios - en un
  !-- BUTTON lo pasa a modo flat y le hace perder el color de fondo. Como el
  !-- motor se aplica dos veces por ventana (Init + evento diferido), sin
  !-- estos IF cada boton recibia el color dos veces y quedaba gris.
  !-- No es una optimizacion: es correccion.
  IF BAND(SELF.Reglas.Acciones, sdAct:Flat)
    IF pFeq{PROP:Flat} <> SELF.Reglas.Flat
      pFeq{PROP:Flat} = SELF.Reglas.Flat
    END
  END

  IF BAND(SELF.Reglas.Acciones, sdAct:Color)
    SELF.PintarFondo(pFeq, SELF.Reglas.Background)
  END

  IF BAND(SELF.Reglas.Acciones, sdAct:FontColor)
    lColor = SELF.Reglas.FontColor
    IF lColor = sdColor:Auto
      IF BAND(SELF.Reglas.Acciones, sdAct:Color)
        lColor = SELF.ContrasteAuto(SELF.Reglas.Background)
      ELSE
        lColor = COLOR:WINDOWTEXT
      END
    END
    IF pFeq{PROP:FontColor} <> lColor
      pFeq{PROP:FontColor} = lColor
    END
  END

  IF BAND(SELF.Reglas.Acciones, sdAct:FontStyle)
    IF pFeq{PROP:FontStyle} <> SELF.Reglas.FontStyle
      pFeq{PROP:FontStyle} = SELF.Reglas.FontStyle
    END
  END

  IF BAND(SELF.Reglas.Acciones, sdAct:Tip)
    IF pFeq{PROP:Tip} <> CLIP(SELF.Reglas.Tip)
      pFeq{PROP:Tip} = CLIP(SELF.Reglas.Tip)
    END
  END

  IF BAND(SELF.Reglas.Acciones, sdAct:Cursor)
    IF pFeq{PROP:Cursor} <> CLIP(SELF.Reglas.Cursor)
      pFeq{PROP:Cursor} = CLIP(SELF.Reglas.Cursor)
    END
  END

  !-- El alto minimo ya no es una accion de regla: es un ajuste fijo, y se
  !-- aplica en AplicarFijos.

!-----------------------------------------------------------------------------!
!  Overrides por ventana
!-----------------------------------------------------------------------------!
SDAspectoClass.OmitControl PROCEDURE(SIGNED pFeq)
  CODE
  CLEAR(SDWinState)
  SDWinState.Feq = pFeq
  GET(SDWinState, SDWinState.Feq)
  IF ERRORCODE()
    CLEAR(SDWinState)
    SDWinState.Feq     = pFeq
    SDWinState.Omitido = 1
    !-- Con clave, igual que en SnapshotControl: si se insertara suelto aca,
    !-- la queue quedaria desordenada y las busquedas volverian a ser lineales.
    ADD(SDWinState, SDWinState.Feq)
  ELSE
    SDWinState.Omitido = 1
    PUT(SDWinState)
  END


SDAspectoClass.ResetWindow PROCEDURE()
lI          LONG
  CODE
  !-- Cada fila puede tener una queue de columnas asignada con NEW: hay que
  !-- liberarla antes de FREE, o se pierde la memoria en cada ventana.
  LOOP lI = 1 TO RECORDS(SDWinState)
    GET(SDWinState, lI)
    IF ERRORCODE() THEN CYCLE.
    IF NOT SDWinState.Columnas &= NULL
      FREE(SDWinState.Columnas)
      DISPOSE(SDWinState.Columnas)
      SDWinState.Columnas &= NULL
      PUT(SDWinState)
    END
  END
  FREE(SDWinState)
  SDWinHandle = 0

  !-- Red de seguridad del congelado. ResetWindow corre en el Kill de cada
  !-- ventana y nunca dentro de una pasada, asi que aca el contador tiene que
  !-- estar en cero. Si no lo esta, alguna pasada se corto por el medio: se
  !-- limpia, porque si no el proximo Congelar de este thread veria el contador
  !-- en uno, no apagaria nada, y el Descongelar dejaria la cuenta corrida.
  IF SDWinGeo.CongelaDepth
    IF SDWinGeo.CongelaHwnd
      SDA:SendMessage(SDWinGeo.CongelaHwnd, WM_SETREDRAW, 1, 0)
    END
    SDWinGeo.CongelaDepth = 0
    SDWinGeo.CongelaHwnd  = 0
  END

!-----------------------------------------------------------------------------!
!  Utilidades
!-----------------------------------------------------------------------------!
SDAspectoClass.NormalizeText PROCEDURE(STRING pTexto)
lRes        STRING(256)
lLen        LONG
lI          LONG
  CODE
  !-- Quita el caracter de acelerador, recorta y pasa a mayusculas, para que
  !-- un caption con acelerador matchee contra el texto plano de la regla.
  lRes = ''
  lLen = 0
  LOOP lI = 1 TO LEN(CLIP(pTexto))
    IF pTexto[lI] = '&' THEN CYCLE.
    lLen += 1
    IF lLen > SIZE(lRes) THEN BREAK.
    lRes[lLen : lLen] = pTexto[lI]
  END
  IF NOT lLen THEN RETURN ''.
  RETURN UPPER(CLIP(LEFT(SUB(lRes, 1, lLen))))


SDAspectoClass.PipeList PROCEDURE(STRING pLista)
lRes        STRING(512)
lItem       STRING(256)
lLargo      LONG
lI          LONG
lCh         STRING(1)
lJ          LONG
  CODE
  !-- Convierte una lista separada por comas en una lista delimitada por
  !-- barras verticales, con delimitador tambien al principio y al final.
  !-- Eso permite buscar un item completo con un solo INSTRING, sin falsos
  !-- positivos por subcadena.
  !--
  !-- Cada item se normaliza IGUAL que NormalizeText (sin '&', recortado y en
  !-- mayusculas) para que los dos lados de la comparacion coincidan. Ojo:
  !-- solo se recortan los espacios de los EXTREMOS, nunca los internos, o un
  !-- texto de varias palabras no matchearia nunca.
  !-- Entrada vacia -> salida vacia. IMPRESCINDIBLE: si devolviera la barra
  !-- inicial sola, LEN(CLIP(Texto)) daria 1 y el criterio de texto se
  !-- activaria con una lista sin items, rechazando TODOS los controles.
  IF NOT LEN(CLIP(pLista)) THEN RETURN ''.
  lRes   = '|'
  lJ     = 0
  lItem  = ''
  lLargo = LEN(CLIP(pLista))
  LOOP lI = 1 TO lLargo + 1
    IF lI > lLargo
      lCh = ','                         !-- cierra el ultimo item
    ELSE
      lCh = pLista[lI]
    END
    IF lCh = ',' OR lCh = '|'
      IF lJ > 0
        lItem = UPPER(CLIP(LEFT(SUB(lItem, 1, lJ))))
        IF LEN(CLIP(lItem))
          lRes = CLIP(lRes) & CLIP(lItem) & '|'
        END
      END
      lJ    = 0
      lItem = ''
    ELSIF lCh <> '&'                    !-- el & es el acelerador, se ignora
      lJ += 1
      IF lJ <= SIZE(lItem)
        lItem[lJ : lJ] = lCh
      END
    END
  END
  RETURN CLIP(lRes)


SDAspectoClass.ComaLista PROCEDURE(STRING pLista)
lRes        STRING(512)
lI          LONG
lJ          LONG
lLargo      LONG
lCh         STRING(1)
  CODE
  !-- Inversa de PipeList: |A|B|C| -> A,B,C
  !-- Se usa al grabar el INI, para que el archivo se pueda editar a mano
  !-- con la misma sintaxis que los prompts del template.
  lRes   = ''
  lJ     = 0
  lLargo = LEN(CLIP(pLista))
  LOOP lI = 1 TO lLargo
    lCh = pLista[lI]
    IF lCh = '|'
      IF lJ = 0 THEN CYCLE.          !-- barra inicial
      IF lI = lLargo THEN CYCLE.     !-- barra final
      lJ += 1
      IF lJ > SIZE(lRes) THEN BREAK.
      lRes[lJ : lJ] = ','
    ELSE
      lJ += 1
      IF lJ > SIZE(lRes) THEN BREAK.
      lRes[lJ : lJ] = lCh
    END
  END
  IF NOT lJ THEN RETURN ''.
  RETURN SUB(lRes, 1, lJ)


SDAspectoClass.EnLista PROCEDURE(STRING pLista, STRING pItem)
  CODE
  IF NOT LEN(CLIP(pItem)) THEN RETURN 0.
  IF INSTRING('|' & CLIP(LEFT(pItem)) & '|', CLIP(pLista), 1, 1)
    RETURN 1
  END
  RETURN 0


SDAspectoClass.TipoToNombre PROCEDURE(LONG pTipo)
  CODE
  CASE pTipo
  OF CREATE:entry
    RETURN 'ENTRY'
  OF CREATE:button
    RETURN 'BUTTON'
  OF CREATE:spin
    RETURN 'SPIN'
  OF CREATE:text
    RETURN 'TEXT'
  OF CREATE:combo
    RETURN 'COMBO'
  OF CREATE:dropcombo
    RETURN 'DROPCOMBO'
  OF CREATE:droplist
    RETURN 'DROPLIST'
  OF CREATE:list
    RETURN 'LIST'
  OF CREATE:check
    RETURN 'CHECK'
  OF CREATE:option
    RETURN 'OPTION'
  OF CREATE:radio
    RETURN 'RADIO'
  OF CREATE:prompt
    RETURN 'PROMPT'
  OF CREATE:string
    RETURN 'STRING'
  OF CREATE:group
    RETURN 'GROUP'
  OF CREATE:sheet
    RETURN 'SHEET'
  OF CREATE:tab
    RETURN 'TAB'
  OF CREATE:region
    RETURN 'REGION'
  OF CREATE:panel
    RETURN 'PANEL'
  END
  RETURN ''


SDAspectoClass.ContrasteAuto PROCEDURE(LONG pFondo)
lR          LONG
lG          LONG
lB          LONG
lLum        LONG
  CODE
  !-- Los colores de Clarion son 00BBGGRRh (BGR, no RGB).
  !-- Si el fondo es un color de sistema (80000000h-8000001Eh) no se puede
  !-- calcular luminancia: se devuelve el color de texto estandar.
  IF BAND(pFondo, 80000000h) OR pFondo = COLOR:NONE
    RETURN COLOR:WINDOWTEXT
  END
  lR   = BAND(pFondo, 0FFh)
  lG   = BAND(BSHIFT(pFondo, -8), 0FFh)
  lB   = BAND(BSHIFT(pFondo, -16), 0FFh)
  lLum = (lR * 299 + lG * 587 + lB * 114) / 1000
  IF lLum > 128
    RETURN 0000000h        !-- fondo claro -> texto negro
  END
  RETURN 0FFFFFFh          !-- fondo oscuro -> texto blanco
