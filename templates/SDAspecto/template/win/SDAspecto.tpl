#TEMPLATE(SDAspecto,'SDAspecto - Personalizacion visual de controles v3.07'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#! SDAspecto - Adrian E. Santarelli - SDigitales
#!
#! Motor de reglas de aspecto visual para controles de ventana.
#! Sucesor de SdTpl.TPL y de BSTheme.
#!
#! Archivos requeridos (copiar a libsrc\win):
#!   SDAspecto.INC   - declaracion de la clase
#!   SDAspecto.CLW   - implementacion del motor
#!
#! Instalacion:
#!   1. Copiar SDAspecto.INC y SDAspecto.CLW a <clarion>\libsrc\win
#!   2. Setup > Template Registry > Add > SDAspecto.TPL
#!   3. En el Application Tree: Global > Extensions > Add > SDAspecto
#!
#! El pintado corre en PRIORITY(8600), tarde en el Init de la ventana, para
#! que cualquier otro template que reaplique fuentes o mueva controles ya
#! haya terminado.
#!-----------------------------------------------------------------------------
#INCLUDE('SDAspecto.tpw')
