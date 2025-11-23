from datetime import datetime, time, date
from flask import Flask, jsonify, request, session
from flask_cors import CORS
import pyodbc

connectionString = "DRIVER={ODBC Driver 17 for SQL Server};SERVER=25.38.209.9,1433;DATABASE=ServiciosDB;UID=Remoto;PWD=1234;"

app = Flask(__name__)
CORS(app, supports_credentials=True)

app.secret_key = 'claveSecreta1234'

def ejecutarSp(nombreSp, parametros=None):
    resultado = None
    conexion = None
    cursor = None
    
    try:
        conexion = pyodbc.connect(connectionString)
        cursor = conexion.cursor()
        
        sqlLlamada = f"EXEC {nombreSp}"
        parametrosSql = []
        parametrosEjecucion = []
        
        if parametros:
            for nombre, valor in parametros.items():
                if nombre.startswith('@'):
                    parametrosSql.append(f"{nombre}=?")
                else:
                    parametrosSql.append(f"@{nombre}=?")
                parametrosEjecucion.append(valor)
        
        if nombreSp == 'ValidarCredenciales':
            parametrosSql.append("@outEsAdmin=?")
            parametrosSql.append("@outResultCode=?")
            outEsAdmin = False
            outResultCode = 0
            parametrosEjecucion.append(outEsAdmin)
            parametrosEjecucion.append(outResultCode)
        else:
            parametrosSql.append("@outResultCode=?")
            outResultCode = 0
            parametrosEjecucion.append(outResultCode)
        
        if parametrosSql:
            sqlLlamada += " " + ", ".join(parametrosSql)
        
        cursor.execute(sqlLlamada, parametrosEjecucion)
        
        resultado = parametrosEjecucion[-1]
        
        conexion.commit()
        
    except Exception as error:
        print(f"Error en ejecutarSp: {error}")
        resultado = -1
        if conexion:
            conexion.rollback()
            
    finally:
        if cursor:
            cursor.close()
        if conexion:
            conexion.close()
    
    return resultado

def ejecutarSpConResultado(nombreSp, parametros=None):
    resultado = None
    conexion = None
    cursor = None
    outResultCode = 0
    
    try:
        conexion = pyodbc.connect(connectionString)
        cursor = conexion.cursor()

        if nombreSp == 'ValidarCredenciales':
            sqlLlamada = """
                DECLARE @admin BIT;
                DECLARE @result INT;
                
                EXEC ValidarCredenciales 
                    @inUserName = ?, 
                    @inPassword = ?, 
                    @inIP = ?, 
                    @outEsAdmin = @admin OUTPUT, 
                    @outResultCode = @result OUTPUT;
                    
                SELECT @admin as EsAdmin, @result as ResultCode;
            """
            parametrosEjecucion = [
                parametros['inUserName'], 
                parametros['inPassword'], 
                parametros['inIP']
            ]
            
            cursor.execute(sqlLlamada, parametrosEjecucion)
            
            fila = cursor.fetchone()
            if fila:
                outEsAdmin = bool(fila.EsAdmin)
                outResultCode = int(fila.ResultCode)
                resultado = [{'esAdmin': outEsAdmin}]
        else:
            sqlLlamada = f"EXEC {nombreSp}"
            parametrosSql = []
            parametrosEjecucion = []
            
            if parametros:
                for nombre, valor in parametros.items():
                    if nombre.startswith('@'):
                        parametrosSql.append(f"{nombre}=?")
                    else:
                        parametrosSql.append(f"@{nombre}=?")
                    parametrosEjecucion.append(valor)

            parametrosSql.append("@outResultCode=?")
            outResultCode = 0
            parametrosEjecucion.append(outResultCode)
            
            if parametrosSql:
                sqlLlamada += " " + ", ".join(parametrosSql)
            
            cursor.execute(sqlLlamada, parametrosEjecucion)
            
            if cursor.description:
                filas = cursor.fetchall()
                columnas = [columna[0] for columna in cursor.description]
                resultado = []
                for fila in filas:
                    filaDict = {}
                    for i, valor in enumerate(fila):
                        if isinstance(valor, (datetime, date)):
                            filaDict[columnas[i]] = valor.isoformat()
                        else:
                            filaDict[columnas[i]] = valor
                    resultado.append(filaDict)

            outResultCode = parametrosEjecucion[-1]
        
        conexion.commit()
        return resultado, outResultCode
        
    except Exception as error:
        print(f"Error ejecutando SP {nombreSp}: {error}")
        outResultCode = -1
        return [], outResultCode
            
    finally:
        if cursor:
            cursor.close()
        if conexion:
            conexion.close()

@app.route('/api/login', methods=['POST'])
def login():
    try:
        datos = request.get_json()
        userName = datos.get('userName')
        password = datos.get('password')
        ip = request.remote_addr
        
        if not userName or not password:
            return jsonify({'success': False, 'message': 'Usuario y contraseña requeridos'}), 400
        
        parametros = {
            'inUserName': userName,
            'inPassword': password,
            'inIP': ip
        }
        
        resultado, outResultCode = ejecutarSpConResultado('ValidarCredenciales', parametros)
        
        if outResultCode == 0 and resultado:
            
            session['userName'] = userName
            session['esAdmin'] = resultado[0].get('esAdmin', False)
            session['ip'] = ip
            
            return jsonify({
                'success': True,
                'message': 'Login exitoso',
                'esAdmin': session['esAdmin'],
                'userName': userName
            })
        else:
            return jsonify({
                'success': False,
                'message': 'Credenciales inválidas'
            }), 401
            
    except Exception as error:
        return jsonify({'success': False, 'message': str(error)}), 500

@app.route('/api/logout', methods=['POST'])
def logout():
    try:
        session.clear()
        return jsonify({'success': True, 'message': 'Logout exitoso'})
    except Exception as error:
        return jsonify({'success': False, 'message': str(error)}), 500

@app.route('/api/buscarPropiedadesPorFinca', methods=['POST'])
def buscarPropiedadesPorFinca():
    try:
        if 'userName' not in session:
            return jsonify({'success': False, 'message': 'No autenticado'}), 401
        
        datos = request.get_json()
        numFinca = datos.get('numFinca')
        
        if not numFinca:
            return jsonify({'success': False, 'message': 'Número de finca requerido'}), 400
        
        parametros = {
            'inNumFinca': numFinca,
            'inUserName': session['userName'],
            'inIP': session.get('ip', request.remote_addr)
        }
        
        resultado, outResultCode = ejecutarSpConResultado('BuscarPropiedadesPorFinca', parametros)
        
        if outResultCode == 0:
            return jsonify({
                'success': True,
                'propiedades': resultado,
                'message': 'Búsqueda exitosa'
            })
        else:
            return jsonify({
                'success': False,
                'message': 'No se encontraron propiedades'
            }), 404
            
    except Exception as error:
        return jsonify({'success': False, 'message': str(error)}), 500

@app.route('/api/adminListarFincasPorDocumento', methods=['POST'])
def adminListarFincasPorDocumento():
    try:
        if 'userName' not in session or not session.get('esAdmin'):
            return jsonify({'success': False, 'message': 'No autorizado'}), 403
        
        datos = request.get_json()
        valorDocumento = datos.get('valorDocumento')
        
        if not valorDocumento:
            return jsonify({'success': False, 'message': 'Documento de identidad requerido'}), 400
        
        parametros = {
            'inValorDocumento': valorDocumento,
            'inUserName': session['userName'],
            'inIP': session.get('ip', request.remote_addr)
        }
        
        resultado, outResultCode = ejecutarSpConResultado('AdminListarFincasPorDocumento', parametros)
        
        if outResultCode == 0:
            return jsonify({
                'success': True,
                'propiedades': resultado,
                'message': 'Búsqueda exitosa'
            })
        else:
            return jsonify({
                'success': False,
                'message': 'No se encontraron propiedades para el documento'
            }), 404
            
    except Exception as error:
        return jsonify({'success': False, 'message': str(error)}), 500

@app.route('/api/facturaObtenerPendienteMasAntigua', methods=['POST'])
def facturaObtenerPendienteMasAntigua():
    try:
        if 'userName' not in session:
            return jsonify({'success': False, 'message': 'No autenticado'}), 401
        
        datos = request.get_json()
        idPropiedad = datos.get('idPropiedad')
        
        if not idPropiedad:
            return jsonify({'success': False, 'message': 'ID de propiedad requerido'}), 400
        
        parametros = {
            'inIDPropiedad': idPropiedad,
            'inUserName': session['userName'],
            'inIP': session.get('ip', request.remote_addr)
        }
        
        resultado, outResultCode = ejecutarSpConResultado('FacturaObtenerPendienteMasAntigua', parametros)
        
        if outResultCode == 0:
            return jsonify({
                'success': True,
                'facturas': resultado,
                'message': 'Factura obtenida exitosamente'
            })
        else:
            return jsonify({
                'success': False,
                'message': 'No hay facturas pendientes'
            }), 404
            
    except Exception as error:
        return jsonify({'success': False, 'message': str(error)}), 500

@app.route('/api/previewFacturaMasAntigua', methods=['POST'])
def previewFacturaMasAntigua():
    try:
        if 'userName' not in session:
            return jsonify({'success': False, 'message': 'No autenticado'}), 401
        
        datos = request.get_json()
        idPropiedad = datos.get('idPropiedad')
        
        if not idPropiedad:
            return jsonify({'success': False, 'message': 'ID de propiedad requerido'}), 400

        conexion = pyodbc.connect(connectionString)
        cursor = conexion.cursor()

        outIDFactura = 0
        outMontoMoratorios = 0
        outTotalPagar = 0
        outResultCode = 0

        cursor.execute("""
            DECLARE @outIDFactura INT;
            DECLARE @outMontoMoratorios MONEY;
            DECLARE @outTotalPagar MONEY;
            DECLARE @outResultCode INT;
            
            EXEC dbo.PreviewFacturaMasAntigua 
                @inIDPropiedad = ?,
                @inUserName = ?,
                @inIP = ?,
                @outIDFactura = @outIDFactura OUTPUT,
                @outMontoMoratorios = @outMontoMoratorios OUTPUT,
                @outTotalPagar = @outTotalPagar OUTPUT,
                @outResultCode = @outResultCode OUTPUT;
                
            SELECT 
                @outIDFactura as IDFactura,
                @outMontoMoratorios as MontoMoratorios,
                @outTotalPagar as TotalPagar,
                @outResultCode as ResultCode;
        """, idPropiedad, session['userName'], session.get('ip', request.remote_addr))
        
        resultado_sp = cursor.fetchone()
        if resultado_sp:
            outIDFactura = resultado_sp.IDFactura or 0
            outMontoMoratorios = float(resultado_sp.MontoMoratorios or 0)
            outTotalPagar = float(resultado_sp.TotalPagar or 0)
            outResultCode = resultado_sp.ResultCode or 0
        
        cursor.close()
        conexion.close()
        
        if outResultCode == 0 and outIDFactura > 0:
            conexion = pyodbc.connect(connectionString)
            cursor = conexion.cursor()
            
            cursor.execute("""
                SELECT 
                    ID,
                    FechaFactura,
                    FechaLimitePago,
                    FechaCorteAgua,
                    IDPropiedad,
                    TotalPagarOriginal,
                    EstadoFactura,
                    IDTipoMedioPago,
                    TotalPagarFinal
                FROM Factura 
                WHERE ID = ?
            """, outIDFactura)
            
            filaFactura = cursor.fetchone()
            cursor.close()
            conexion.close()
            
            if filaFactura:
                factura = {
                    'ID': filaFactura.ID,
                    'FechaFactura': filaFactura.FechaFactura.isoformat() if filaFactura.FechaFactura else None,
                    'FechaLimitePago': filaFactura.FechaLimitePago.isoformat() if filaFactura.FechaLimitePago else None,
                    'FechaCorteAgua': filaFactura.FechaCorteAgua.isoformat() if filaFactura.FechaCorteAgua else None,
                    'IDPropiedad': filaFactura.IDPropiedad,
                    'TotalPagarOriginal': float(filaFactura.TotalPagarOriginal or 0),
                    'EstadoFactura': filaFactura.EstadoFactura,
                    'IDTipoMedioPago': filaFactura.IDTipoMedioPago,
                    'TotalPagarFinal': float(filaFactura.TotalPagarFinal or 0),
                    'MontoMoratorios': outMontoMoratorios,
                    'TotalPagar': outTotalPagar
                }
                
                return jsonify({
                    'success': True,
                    'factura': factura,
                    'message': 'Preview generado exitosamente'
                })
        
        return jsonify({
            'success': False,
            'message': 'No se pudo generar el preview de la factura'
        }), 400
            
    except Exception as error:
        print(f"Error en previewFacturaMasAntigua: {error}")
        return jsonify({'success': False, 'message': str(error)}), 500
    
@app.route('/api/confirmarFacturaMasAntigua', methods=['POST'])
def confirmarFacturaMasAntigua():
    try:
        if 'userName' not in session:
            return jsonify({'success': False, 'message': 'No autenticado'}), 401
        
        datos = request.get_json()
        idFactura = datos.get('idFactura')
        tipoMedioPago = datos.get('tipoMedioPago', 1)
        
        if not idFactura:
            return jsonify({'success': False, 'message': 'ID de factura requerido'}), 400

        conexion = pyodbc.connect(connectionString)
        cursor = conexion.cursor()

        outCodigoComprobante = ''
        outResultCode = 0

        cursor.execute("""
            DECLARE @outCodigoComprobante VARCHAR(32);
            DECLARE @outResultCode INT;
            
            EXEC dbo.ConfirmarFacturaMasAntigua 
                @inIDFactura = ?,
                @inTipoMedioPago = ?,
                @inUserName = ?,
                @inIP = ?,
                @outCodigoComprobante = @outCodigoComprobante OUTPUT,
                @outResultCode = @outResultCode OUTPUT;
                
            SELECT 
                @outCodigoComprobante as CodigoComprobante,
                @outResultCode as ResultCode;
        """, idFactura, tipoMedioPago, session['userName'], session.get('ip', request.remote_addr))

        resultado = cursor.fetchone()
        if resultado:
            outCodigoComprobante = resultado.CodigoComprobante or ''
            outResultCode = resultado.ResultCode or 0
        conexion.commit()
        
        cursor.close()
        conexion.close()
        
        
        if outResultCode == 0:
            return jsonify({
                'success': True,
                'comprobante': outCodigoComprobante,
                'message': 'Pago confirmado exitosamente'
            })
        else:
            mensajeError = 'No se pudo confirmar el pago'
            if outResultCode == 50001:
                mensajeError = 'Factura no encontrada'
            elif outResultCode == 50008:
                mensajeError = 'Error en la base de datos'
                
            return jsonify({
                'success': False,
                'message': mensajeError
            }), 400
            
    except Exception as error:
        print(f"Error en confirmarFacturaMasAntigua: {error}")
        return jsonify({'success': False, 'message': str(error)}), 500

@app.route('/api/dashboard', methods=['GET'])
def obtenerDashboard():
    try:
        if 'userName' not in session:
            return jsonify({'success': False, 'message': 'No autenticado'}), 401

        conexion = pyodbc.connect(connectionString)
        cursor = conexion.cursor()

        outResultCode = 0

        cursor.execute("""
            DECLARE @outTotalPropiedades INT;
            DECLARE @outFacturasPendientes INT;
            DECLARE @outRecaudacionMes MONEY;
            DECLARE @outCortesProgramados INT;
            DECLARE @outResultCode INT;
            
            EXEC dbo.DashboardObtenerEstadisticas 
                @inUserName = ?,
                @inIP = ?,
                @outTotalPropiedades = @outTotalPropiedades OUTPUT,
                @outFacturasPendientes = @outFacturasPendientes OUTPUT,
                @outRecaudacionMes = @outRecaudacionMes OUTPUT,
                @outCortesProgramados = @outCortesProgramados OUTPUT,
                @outResultCode = @outResultCode OUTPUT;
                
            SELECT 
                @outTotalPropiedades as TotalPropiedades,
                @outFacturasPendientes as FacturasPendientes,
                @outRecaudacionMes as RecaudacionMes,
                @outCortesProgramados as CortesProgramados,
                @outResultCode as ResultCode;
        """, session['userName'], session.get('ip', request.remote_addr))

        resultado = cursor.fetchone()
        if resultado:
            estadisticas = {
                'totalPropiedades': resultado.TotalPropiedades or 0,
                'facturasPendientes': resultado.FacturasPendientes or 0,
                'recaudacionMes': float(resultado.RecaudacionMes or 0),
                'cortesProgramados': resultado.CortesProgramados or 0
            }
            outResultCode = resultado.ResultCode or 0
        
        cursor.close()
        conexion.close()
        
        if outResultCode == 0:
            return jsonify({
                'success': True,
                'estadisticas': estadisticas,
                'message': 'Datos del dashboard obtenidos'
            })
        else:
            return jsonify({
                'success': False,
                'message': 'Error al obtener datos del dashboard'
            }), 400
        
    except Exception as error:
        print(f"Error en dashboard: {error}")
        return jsonify({'success': False, 'message': str(error)}), 500
    
@app.route('/api/verificarSesion', methods=['GET'])
def verificarSesion():
    try:
        if 'userName' in session:
            return jsonify({
                'success': True,
                'autenticado': True,
                'userName': session['userName'],
                'esAdmin': session.get('esAdmin', False)
            })
        else:
            return jsonify({
                'success': True,
                'autenticado': False
            })
    except Exception as error:
        return jsonify({'success': False, 'message': str(error)}), 500
