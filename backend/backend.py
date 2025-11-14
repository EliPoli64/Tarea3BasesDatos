from datetime import datetime, time, date
from flask import Flask, jsonify, request, session
from flask_cors import CORS
import pyodbc

connectionString = "DRIVER={ODBC Driver 17 for SQL Server};SERVER=25.38.209.9,1433;DATABASE=ServiciosDB;UID=Remoto;PWD=1234;"

app = Flask(__name__)
CORS(app, supports_credentials=True)

app.secret_key = 'claveSecreta1234'

def ejecutarSP(nombreSp, parametros=None):
    resultado = None
    conexion = None
    cursor = None
    
    try:
        conexion = pyodbc.connect(connectionString)
        cursor = conexion.cursor()
        
        sqlLlamada = f"EXEC {nombreSp}"
        parametrosSql = []
        
        if parametros:
            for nombre, valor in parametros.items():
                if nombre.startswith('@'):
                    parametrosSql.append(f"{nombre}=?")
                else:
                    parametrosSql.append(f"@{nombre}=?")
        
        parametrosSql.append("@outResultCode=?")
        
        if parametrosSql:
            sqlLlamada += " " + ", ".join(parametrosSql)
        
        parametrosEjecucion = []
        if parametros:
            for nombre, valor in parametros.items():
                parametrosEjecucion.append(valor)
        
        parametrosEjecucion.append(0)
        
        cursor.execute(sqlLlamada, parametrosEjecucion)
        
        resultado = parametrosEjecucion[-1]
        
        conexion.commit()
        
    except Exception as error:
        resultado = -1
        if conexion:
            conexion.rollback()
            
    finally:
        if cursor:
            cursor.close()
        if conexion:
            conexion.close()
    
    return resultado

app.run(host="0.0.0.0", port=5000)