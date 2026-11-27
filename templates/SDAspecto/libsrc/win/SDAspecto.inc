!ABCIncludeFile
OMIT('_EndOfInclude_',_SDAspectoPresent_)
_SDAspectoPresent_      EQUATE(1)
! SDAspecto - Personalizacion visual de controles
! Adrian E. Santarelli - SDigitales
! Fase 1: motor de reglas de color. Ver PLAN.md.

!-- ICriticalSection + el MAP de NewCriticalSection(). Va CWSYNCHM.INC y no
!-- CWSYNCHC.INC: este ultimo trae solo las clases envoltorio y la interface,
!-- sin el prototipo de la factory. Es el mismo include que usa ABFILE.INC.
!-- La instancia de la clase es unica y global, y en una app MDI la llaman
!-- todos los threads a la vez: la queue de reglas necesita un lock.
    INCLUDE('CWSYNCHM.INC'),ONCE

SDAspecto:Version       EQUATE('3.07')

!-- Evento propio para re-aplicar una vez que la ventana termino de armarse.
!-- En Init todavia hay codigo de ABC por correr (restauracion de posicion
!-- desde el INI, resizers) que puede pisar lo que hacemos. Se postea el
!-- evento al final del Init y se reaplica al recibirlo, cuando ya no queda
!-- nadie atras. Es seguro porque el motor es idempotente.
!-- Rango valido: EVENT:User(400h) .. EVENT:Last(FFFh).
SDAspecto:EventoRefresh EQUATE(0A51h)

!-- Modo de evaluacion de un criterio booleano (Req, ReadOnly, Disable) -------
sdTest:Ignorar          EQUATE(0)   !-- el criterio no participa del match
sdTest:Si               EQUATE(1)   !-- la propiedad debe estar en 1
sdTest:No               EQUATE(2)   !-- la propiedad debe estar en 0

!-- Modo de comparacion de texto ---------------------------------------------
sdText:Exacto           EQUATE(0)
sdText:Contiene         EQUATE(1)
sdText:Empieza          EQUATE(2)

!-- Bitmask de acciones: declara QUE campos de la regla estan definidos.
!-- Necesario porque COLOR:NONE = -1 es un color valido y no sirve de centinela.
sdAct:Color        EQUATE(00001h)
sdAct:FontColor         EQUATE(00002h)
sdAct:FontStyle         EQUATE(00004h)
sdAct:Flat              EQUATE(00008h)
sdAct:Tip               EQUATE(00010h)
sdAct:Cursor            EQUATE(00020h)

!-- Como se decide que un campo es obligatorio. Es un bitmask.
!-- El atributo REQ es lo limpio, pero muchas apps no lo usan y marcan los
!-- campos poniendoles un fondo en el disenador: SdTpl.TPL se apoyaba en eso.
sdReq:AtributoREQ       EQUATE(1)
sdReq:FondoDisenio      EQUATE(2)
sdReq:Ambos             EQUATE(3)

!-- Centinela: derivar el color de fuente por luminancia del fondo.
!-- 7FFFFFFFh esquiva tanto los colores reales (00BBGGRRh) como los
!-- colores de sistema (80000000h-8000001Eh).
sdColor:Auto            EQUATE(7FFFFFFFh)

!-----------------------------------------------------------------------------!
!  Una regla = criterios de match + acciones.
!  Se evaluan en orden; todas las que matchean aplican (cascada tipo CSS) y la
!  ultima gana por propiedad. Cortar=1 corta la cascada para ese control.
!-----------------------------------------------------------------------------!
SDRuleQType             QUEUE,TYPE
Nombre                    STRING(32)
Orden                     LONG
Activa                    BYTE
!-- criterios (solo propiedades que las acciones NO modifican) ---------------
Tipos                     STRING(160)   !-- lista delimitada, ya normalizada
Texto                     STRING(512)   !-- lista delimitada, ya normalizada
ModoTexto                 BYTE          !-- sdText:xxx
Picture                   STRING(64)    !-- wildcard sobre PROP:Text
TestReq                   BYTE          !-- sdTest:xxx, via EsRequerido()
TestReadOnly              BYTE
TestDisable               BYTE
!-- acciones ----------------------------------------------------------------
Acciones                  LONG          !-- bitmask sdAct:xxx
Background                LONG
FontColor                 LONG          !-- o sdColor:Auto
FontStyle                 LONG
Flat                      BYTE
Tip                       STRING(255)
Cursor                    STRING(32)
Cortar                    BYTE          !-- 1 = corta la cascada (semantica ELSIF)
                        END

!-----------------------------------------------------------------------------!
!  Estado por ventana.
!
!  En Fase 1 solo se usa para llevar la lista de controles omitidos. Se declara
!  ya con los campos de geometria porque el rescalado de la Fase 4 los va a
!  necesitar, y agregar estado por ventana despues es mucho mas caro.
!
!  IMPORTANTE: la instancia global de la clase es compartida entre threads, asi
!  que la queue de estado se declara ,THREAD en SDAspecto.CLW.
!-----------------------------------------------------------------------------!
!-- Parametros de una fuente, para comparar la vieja contra la nueva.
SDFontType              GROUP,TYPE
Nombre                    STRING(64)
Tamano                    LONG
Color                     LONG
Estilo                    LONG
Charset                   LONG
                        END

!-- Anchos de columna de un LIST/COMBO. No hay que parsear PROP:Format: los
!-- anchos son propiedades indexadas (PROPLIST:width, PROPLIST:group).
SDColWQType             QUEUE,TYPE
Ancho                     LONG
Grupo                     LONG
AnchoGrupo                LONG
                        END

!-----------------------------------------------------------------------------!
!  Geometria y tipografia de la ventana en curso.
!
!  Se declara como TYPE y se instancia ,THREAD en SDAspecto.CLW, igual que
!  SDWinStateQType. Instanciar un GROUP suelto a nivel de modulo promoveria los
!  nombres de sus campos al scope del modulo, y FteVieja y FteNueva comparten
!  los de SDFontType: seria un label duplicado.
!
!  Esto vivia como propiedades de la clase, y ahi estaba MAL: la instancia es
!  unica y global, asi que dos ventanas abriendose en threads distintos se
!  pisaban los valores.
!-----------------------------------------------------------------------------!
SDWinGeoType            GROUP,TYPE
OrigClientH               LONG          !-- alto de area cliente antes del cambio
OrigMinWidth              LONG          !-- minimos de la ventana, en dialog units
OrigMinHeight             LONG
!-- Posicion y tamano de la ventana en PIXELES, antes del cambio de fuente.
!-- En pixeles y no en dialog units a proposito: la unidad de dialogo es lo
!-- que acaba de cambiar de tamano, asi que no sirve para comparar antes
!-- contra despues.
OrigWinX                  LONG
OrigWinY                  LONG
OrigWinW                  LONG
OrigWinH                  LONG
!-- Fuente vieja de la ventana y fuente nueva ya resuelta. Se comparan campo
!-- por campo: en cada control solo se reemplaza lo que coincide con la vieja,
!-- para no pisar controles a los que les pusiste otra tipografia a proposito.
FteVieja                  GROUP(SDFontType)
                          END
FteNueva                  GROUP(SDFontType)
                          END
!-- Congelado del repintado. Se guarda el HWND que se congelo y no se relee
!-- 0{PROP:Handle} al descongelar, para garantizar que se descongela
!-- exactamente lo mismo que se congelo aunque cambie la ventana activa.
!-- El contador permite anidar sin que un Descongelar de adentro prenda el
!-- repintado antes de tiempo.
CongelaHwnd               UNSIGNED
CongelaDepth              LONG
                        END

SDWinStateQType         QUEUE,TYPE
Feq                       SIGNED
Omitido                   BYTE          !-- excluido por el desarrollador
Saltar                    BYTE          !-- excluido por tipo (sublist, toolbar)
Snapshot                  BYTE          !-- 1 = los campos Orig tienen datos
!-- Fondo que el control traia del disenador, capturado ANTES de que ninguna
!-- regla lo toque. Permite usar "tiene fondo propio" como criterio de campo
!-- obligatorio sin romper la idempotencia.
OrigBackground            LONG
!-- Geometria original en DIALOG UNITS, no en pixeles. Esa es la clave del
!-- rescalado: el dialog unit se define en funcion de la fuente, asi que
!-- reescribir los MISMOS numeros despues de cambiar la tipografia reescala
!-- la ventana sola. No hace falta calcular ningun factor.
OrigXpos                  LONG
OrigYpos                  LONG
OrigWidth                 LONG
OrigHeight                LONG
OrigLineHeight            LONG          !-- solo LIST y COMBO
OrigAngulo                LONG          !-- texto rotado
Columnas                  &SDColWQType  !-- solo LIST y COMBO
                        END

!-----------------------------------------------------------------------------!
!  Clase principal. Instancia unica global, declarada por el template.
!-----------------------------------------------------------------------------!
SDAspectoClass          CLASS,TYPE,MODULE('SDAspecto.CLW'),LINK('SDAspecto.CLW',_ABCLinkMode_),DLL(_ABCDllMode_)

Reglas                    &SDRuleQType
Esquema                   CSTRING(65)
IniFile                   CSTRING(261)
Deshabilitado             BYTE
Diagnostico               BYTE          !-- 1 = mostrar que ve el motor
ModoRequerido             BYTE          !-- bitmask sdReq:xxx

!-- Tipografia global. Convencion: -1 (o cadena vacia para el
!-- nombre) significa NO tocar ese parametro. Son campos publicos a proposito:
!-- un dialogo de fuente en runtime los puede modificar y llamar a Refresh.
FuenteActiva              BYTE
FuenteAVentana            BYTE
FuenteAControles          BYTE
FuenteNombre              CSTRING(65)
FuenteTamano              LONG
FuenteEstilo              LONG
FuenteColor               LONG
FuenteCharset             LONG

!-- NO van aca la fuente vieja/nueva ni la geometria original de la ventana.
!-- Son estado POR VENTANA, y esta instancia es unica y compartida por todos
!-- los threads: si vivieran aca, dos ventanas abriendose a la vez se pisarian
!-- los valores entre el snapshot y la restauracion. Estan en el grupo
!-- SDWinGeo, declarado ,THREAD en SDAspecto.CLW, al lado de SDWinState.

!-- AJUSTES FIJOS. No son reglas: una regla es CONDICIONAL, esto se aplica
!-- siempre y por igual, como la tipografia. Se aplican ANTES que las reglas,
!-- asi que una regla puede pisarlos en un control puntual.
!-- Convencion: -1 = no aplicar.
!-- NO existe ColorGroup: un GROUP no es una superficie rellenable. Para
!-- colorear el area de un grupo va un PANEL o REGION detras.
!-- ColorTab SI existe, pero requiere desactivar el estilo visual en el
!-- manifiesto de la aplicacion; con el estilo activo, Windows lo ignora.
AltoMinimo                LONG          !-- 0 o -1 = no forzar alto
ColorTab                  LONG
ColorSheet                LONG
ColorPanel                LONG
ColorRegion               LONG
ColorList                 LONG
ColorCombo                LONG
ColorOption               LONG
ColorSpin                 LONG
ColorText                 LONG

!-- Rescalado de geometria al cambiar la tipografia.
RescalarActivo            BYTE
RescalarVentana           BYTE
PreservarMenu             BYTE          !-- no tocar MENU / MENUBAR / ITEM
PreservarToolbar          BYTE          !-- no tocar la TOOLBAR ni lo que contiene
RecentrarVentana          BYTE          !-- mantener el centro tras el rescalado

!-- Convivencia con el resizer de ABC (WindowResizeClass).
!-- Resizer.Init corre en prioridad 8125 y ahi captura, con Reset(), la
!-- posicion y el tamano de CADA control como linea base. Nosotros corremos en
!-- 8600 y le movemos todo despues, asi que su base queda obsoleta y el primer
!-- EVENT:Sized recalcula desde numeros que ya no existen.
!-- Ademas Resizer.Init administra PROP:MinWidth/MinHeight (Resize:SetMinSize)
!-- y ABC puede fijar MaxWidth/MaxHeight; pisarlos puede dejar el minimo por
!-- encima del maximo y la ventana no se redimensiona mas.
!-- En 1: no se tocan esas propiedades. La re-sincronizacion de la linea base
!-- la emite el template llamando a Reset() despues de la pasada diferida.
RespetarResizer           BYTE

!-- Congelar el repintado durante la pasada (WM_SETREDRAW). Evita ver como los
!-- controles se mueven y se pintan de a uno, pero es EXPERIMENTAL: en 3.02,
!-- aplicado siempre, rompio el frame de una aplicacion MDI. Por defecto 0.
!-- Aun en 1 solo se aplica a ventanas MDI hijas, nunca al frame.
CongelarActivo            BYTE

!-- Lock de la queue de reglas. Clarion NO protege una QUEUE compartida entre
!-- threads: dos GET concurrentes alcanzan para corromper el indice interno.
!-- Se crea en Construct y se libera en Destruct.
Lock                      &ICriticalSection

Construct                 PROCEDURE()
Destruct                  PROCEDURE()

Init                      PROCEDURE(STRING pEsquema)
Kill                      PROCEDURE()

!-- Persistencia. El INI guarda TODO el estado: los parametros globales y la
!-- lista completa de reglas, una seccion [Regla:n] por cada una. Asi una
!-- ventana de configuracion puede editar cualquier cosa y grabarla.
CargarIni                 PROCEDURE(<STRING pArchivo>),BYTE,PROC
GuardarIni                PROCEDURE(<STRING pArchivo>),BYTE,PROC

!-- Esquema de fabrica, en codigo. Las reglas son DATOS: viven en el INI y se
!-- editan desde la ventana de configuracion. Esto es solo el punto de partida
!-- para cuando todavia no hay archivo.
CargarDefaults            PROCEDURE(),VIRTUAL

!-- Arranque: intenta el INI y, si no trajo reglas, arma las de fabrica y las
!-- graba. Una sola llamada desde el template.
Arrancar                  PROCEDURE(STRING pArchivo)

!-- Carga de reglas. En Fase 1 solo AddRule (el template genera las llamadas).
AddRule                   PROCEDURE(STRING pNombre, STRING pTipos),LONG,PROC
SetMatch                  PROCEDURE(LONG pRegla, BYTE pReq, BYTE pReadOnly, BYTE pDisable)
SetTexto                  PROCEDURE(LONG pRegla, STRING pTextos, BYTE pModo)
SetPicture                PROCEDURE(LONG pRegla, STRING pPattern)
SetAccion                 PROCEDURE(LONG pRegla, LONG pAccion, LONG pValor)
SetTip                    PROCEDURE(LONG pRegla, STRING pTip)
SetPuntero                 PROCEDURE(LONG pRegla, STRING pCursor)
SetCortar                 PROCEDURE(LONG pRegla, BYTE pCortar)

!-- Aplicacion
ApplyToWindow             PROCEDURE()
TakeEvent                 PROCEDURE(),VIRTUAL
Diagnosticar              PROCEDURE(),VIRTUAL
FondoOriginal             PROCEDURE(SIGNED pFeq),LONG
ApplyToControl            PROCEDURE(SIGNED pFeq),VIRTUAL
Matches                   PROCEDURE(SIGNED pFeq, LONG pRegla),BYTE,VIRTUAL
ApplyRule                 PROCEDURE(SIGNED pFeq, LONG pRegla),VIRTUAL
ResolverFuente            PROCEDURE()
AplicarFuenteA            PROCEDURE(SIGNED pFeq),VIRTUAL
AplicarFijos              PROCEDURE(SIGNED pFeq),VIRTUAL
PintarFondo               PROCEDURE(SIGNED pFeq, LONG pColor),VIRTUAL
FondoActual               PROCEDURE(SIGNED pFeq),LONG

!-- Congelado del repintado durante la pasada. Sin esto, en una ventana con
!-- muchos controles se ve como cada control se mueve y se pinta de a uno, con
!-- el fondo sin borrar asomando en el medio.
CongelarPintura           PROCEDURE()
DescongelarPintura        PROCEDURE()

!-- Rescalado
RefrescarPixels           PROCEDURE()
RestaurarGeometria        PROCEDURE(),VIRTUAL
CentrarVentana            PROCEDURE(),VIRTUAL
DebeSaltar                PROCEDURE(SIGNED pFeq),BYTE,VIRTUAL

!-- Estado por ventana / deteccion de obligatorios
SnapshotControl           PROCEDURE(SIGNED pFeq)
TieneFondoPropio          PROCEDURE(SIGNED pFeq),BYTE
EsRequerido               PROCEDURE(SIGNED pFeq),BYTE,VIRTUAL

!-- Overrides por ventana
OmitControl               PROCEDURE(SIGNED pFeq)
ResetWindow               PROCEDURE()

!-- Exclusion mutua sobre la queue de reglas.
!-- Los metodos de la clase ya se protegen solos. Esto es para el codigo que
!-- toca SELF.Reglas DESDE AFUERA: la ventana de configuracion hace ADD, PUT,
!-- DELETE y GET directo sobre la queue, y si lo hace mientras otra ventana MDI
!-- se esta abriendo, el thread que esta iterando recorre memoria liberada.
!-- Envolver ahi: Bloquear() ... Liberar(), siempre en par.
!-- Es re-entrante para el mismo thread (Windows CRITICAL_SECTION), asi que
!-- anidar no traba.
Bloquear                  PROCEDURE()
Liberar                   PROCEDURE()

!-- Utilidades
NormalizeText             PROCEDURE(STRING pTexto),STRING
SinBarras                 PROCEDURE(STRING pTexto),STRING
PipeList                  PROCEDURE(STRING pLista),STRING
ComaLista                 PROCEDURE(STRING pLista),STRING
EnLista                    PROCEDURE(STRING pLista, STRING pItem),BYTE
TipoToNombre              PROCEDURE(LONG pTipo),STRING
ContrasteAuto             PROCEDURE(LONG pFondo),LONG

                        END

  _EndOfInclude_
