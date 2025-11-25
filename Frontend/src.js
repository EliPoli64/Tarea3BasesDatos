const API_BASE = 'http://25.38.209.9:5000/api';

document.querySelectorAll('.nav-item').forEach(itemMenu => {
    itemMenu.addEventListener('click', function() {
        document.querySelectorAll('.nav-item').forEach(nav => nav.classList.remove('active'));
        this.classList.add('active');
        
        const idSeccion = this.getAttribute('data-section');
        document.querySelectorAll('.section').forEach(seccion => seccion.classList.remove('active'));
        document.getElementById(idSeccion).classList.add('active');
        
        document.getElementById('tituloPagina').textContent = this.textContent.trim();
    });
});

document.querySelectorAll('.tab').forEach(pestaña => {
    pestaña.addEventListener('click', function() {
        document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
        this.classList.add('active');
        
        const idpestana = this.getAttribute('data-tab');
        document.querySelectorAll('.tab-content').forEach(contenido => contenido.style.display = 'none');
        document.getElementById(idpestana + 'Tab').style.display = 'block';
    });
});

document.getElementById('formularioInicioSesion').addEventListener('submit', async function(e) {
    e.preventDefault();
    
    const nombreUsuario = document.getElementById('nombreUsuario').value;
    const contrasena = document.getElementById('contrasena').value;
    
    try {
        const respuesta = await fetch(`${API_BASE}/login`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                userName: nombreUsuario,
                password: contrasena
            }),
            credentials: 'include'
        });
        
        const datos = await respuesta.json();
        
        if (datos.success) {
            document.getElementById('pantallaInicioSesion').style.display = 'none';
            document.getElementById('app').style.display = 'flex';
            document.getElementById('nombreUsuarioDisplay').textContent = datos.userName;
            document.getElementById('avatarUsuario').textContent = datos.userName.charAt(0).toUpperCase();
            cargarDashboard();
        } else {
            alert('Error: ' + datos.message);
        }
    } catch (error) {
        alert('Error de conexión: ' + error.message);
    }
});

document.getElementById('btnCerrarSesion').addEventListener('click', async function() {
    try {
        await fetch(`${API_BASE}/logout`, {
            method: 'POST',
            credentials: 'include'
        });
        
        document.getElementById('app').style.display = 'none';
        document.getElementById('pantallaInicioSesion').style.display = 'flex';
        document.getElementById('formularioInicioSesion').reset();
    } catch (error) {
        console.error('Error al cerrar sesión:', error);
    }
});

document.getElementById('btnBuscarFinca').addEventListener('click', async function() {
    const finca = document.getElementById('busquedaFinca').value;
    if (finca) {
        try {
            const respuesta = await fetch(`${API_BASE}/buscarPropiedadesPorFinca`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ numFinca: finca }),
                credentials: 'include'
            });
            
            const datos = await respuesta.json();
            
            if (datos.success && datos.propiedades && datos.propiedades.length > 0) {
                const propiedad = datos.propiedades[0];
                document.getElementById('resultadosBusqueda').innerHTML = `
                    <div class="card">
                        <div class="card-content">
                            <h3>Propiedad Encontrada</h3>
                            <p><strong>Número de Finca:</strong> ${propiedad.NumFinca}</p>
                            <p><strong>Área:</strong> ${propiedad.Area} m²</p>
                            <p><strong>Valor Fiscal:</strong> ₡ ${Number(propiedad.ValorPropiedad).toLocaleString()}</p>
                            <p><strong>Tipo de Uso:</strong> ${propiedad.TipoUso}</p>
                            <p><strong>Zona:</strong> ${propiedad.TipoArea}</p>
                            <button class="btn btn-primary" onclick="verFacturasPropiedad(${propiedad.ID})">
                                Ver Facturas
                            </button>
                        </div>
                    </div>
                `;
            } else {
                document.getElementById('resultadosBusqueda').innerHTML = `
                    <div class="card">
                        <div class="card-content">
                            <p>No se encontró la propiedad</p>
                        </div>
                    </div>
                `;
            }
        } catch (error) {
            alert('Error al buscar propiedad: ' + error.message);
        }
    }
});

document.getElementById('btnBuscarDocumento').addEventListener('click', async function() {
    const documento = document.getElementById('busquedaDocumento').value;
    if (documento) {
        try {
            const respuesta = await fetch(`${API_BASE}/buscarPropiedadesPorDocumento`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ valorDocumento: documento }),
                credentials: 'include'
            });
            
            const datos = await respuesta.json();
            
            if (datos.success && datos.propiedades && datos.propiedades.length > 0) {
                let propiedadesHTML = '';
                datos.propiedades.forEach(propiedad => {
                    propiedadesHTML += `
                        <div class="invoice-item" onclick="seleccionarPropiedad(${propiedad.ID})">
                            <div class="invoice-icon">
                                <i class="fas fa-home"></i>
                            </div>
                            <div class="invoice-details">
                                <div class="invoice-number">${propiedad.NumFinca}</div>
                                <div class="invoice-date">${propiedad.TipoUso} - ${propiedad.Area} m²</div>
                            </div>
                        </div>
                    `;
                });
                
                document.getElementById('resultadosBusqueda').innerHTML = `
                    <div class="card">
                        <div class="card-content">
                            <h3>Propiedades del Propietario</h3>
                            <p><strong>Documento:</strong> ${documento}</p>
                            <div class="invoice-list">
                                ${propiedadesHTML}
                            </div>
                        </div>
                    </div>
                `;
            } else {
                document.getElementById('resultadosBusqueda').innerHTML = `
                    <div class="card">
                        <div class="card-content">
                            <p>No se encontraron propiedades para este documento</p>
                        </div>
                    </div>
                `;
            }
        } catch (error) {
            alert('Error al buscar propiedades: ' + error.message);
        }
    }
});

async function cargarDashboard() {
    try {
        const respuesta = await fetch(`${API_BASE}/dashboard`, {
            method: 'GET',
            credentials: 'include'
        });
        
        const datos = await respuesta.json();
        
        if (datos.success && datos.estadisticas) {
            document.getElementById('totalPropiedades').textContent = datos.estadisticas.totalPropiedades?.toLocaleString() || '0';
            document.getElementById('recaudacionMes').textContent = '₡ ' + (Number(datos.estadisticas.recaudacionMes) || 0).toLocaleString();
            document.getElementById('facturasPendientes').textContent = datos.estadisticas.facturasPendientes?.toLocaleString() || '0';
            document.getElementById('cortesProgramados').textContent = datos.estadisticas.cortesProgramados?.toLocaleString() || '0';
        } else {
            console.error('Error en dashboard:', datos.message);
        }
    } catch (error) {
        console.error('Error al cargar dashboard:', error);
    }
}

window.verFacturasPropiedad = function(idPropiedad) {
    document.querySelector('[data-section="payments"]').click();
    mostrarFacturasPropiedad(idPropiedad);
};

window.seleccionarPropiedad = function(idPropiedad) {
    document.querySelector('[data-section="payments"]').click();
    mostrarFacturasPropiedad(idPropiedad);
};

async function mostrarFacturasPropiedad(idPropiedad) {
    try {
        const respuesta = await fetch(`${API_BASE}/listarFacturasPendientes`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ idPropiedad: idPropiedad }),
            credentials: 'include'
        });
        
        const datos = await respuesta.json();
        
        if (datos.success) {
            let facturasHTML = '';
            datos.facturas.forEach(factura => {
                const fechaVencimiento = new Date(factura.FechaLimitePago);
                const hoy = new Date();
                const vencida = fechaVencimiento < hoy;
                const estado = vencida ? 'status-overdue' : 'status-pending';
                const textoEstado = vencida ? 'Vencida' : 'Pendiente';
                
                facturasHTML += `
                    <div class="invoice-item" onclick="mostrarPrevisualizacionPago(${factura.ID}, ${factura.TotalPagarFinal}, ${idPropiedad})">
                        <div class="invoice-icon">
                            <i class="fas fa-file-invoice-dollar"></i>
                        </div>
                        <div class="invoice-details">
                            <div class="invoice-number">Factura #${factura.ID}</div>
                            <div class="invoice-date">Vence: ${fechaVencimiento.toLocaleDateString()} • ${textoEstado}</div>
                        </div>
                        <div class="invoice-amount">₡ ${Number(factura.TotalPagarFinal).toLocaleString()}</div>
                        <div class="invoice-status ${estado}">${textoEstado}</div>
                    </div>
                `;
            });
            
            document.getElementById('infoPropiedad').innerHTML = `
                <div class="card">
                    <div class="card-content">
                        <h3>Propiedad ID: ${idPropiedad}</h3>
                        <p>Facturas pendientes de pago</p>
                    </div>
                </div>
            `;

            document.getElementById('listaFacturas').innerHTML = `
                <div class="invoice-list">
                    ${facturasHTML}
                </div>
            `;
        } else {
            document.getElementById('listaFacturas').innerHTML = `
                <div class="card">
                    <div class="card-content">
                        <p>No hay facturas pendientes para esta propiedad</p>
                    </div>
                </div>
            `;
        }
    } catch (error) {
        alert('Error al cargar facturas: ' + error.message);
    }
}

window.mostrarPrevisualizacionPago = async function(idFactura, montoTotal, idPropiedad) {
    console.log('ID Factura:', idFactura);
    console.log('ID Propiedad:', idPropiedad);
    
    try {
        const respuesta = await fetch(`${API_BASE}/previewFacturaMasAntigua`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ idPropiedad: idPropiedad }),
            credentials: 'include'
        });
        
        const datos = await respuesta.json();
        
        if (datos.success) {
            const factura = datos.factura;
            const montoOriginal = factura.TotalPagarOriginal || montoTotal;
            const moratorios = factura.MontoMoratorios || 0;
            const total = factura.TotalPagar || montoTotal;
            
            document.getElementById('previsualizacionPago').innerHTML = `
                <div class="card">
                    <div class="card-header">
                        <div class="card-title">Confirmar Pago</div>
                    </div>
                    <div class="card-content">
                        <div class="payment-details">
                            <div class="detail-row">
                                <span class="detail-label">Factura:</span>
                                <span class="detail-value">#${factura.ID}</span>
                            </div>
                            <div class="detail-row">
                                <span class="detail-label">Monto Original:</span>
                                <span class="detail-value">₡ ${Number(montoOriginal).toLocaleString()}</span>
                            </div>
                            ${moratorios > 0 ? `
                            <div class="detail-row">
                                <span class="detail-label">Intereses Moratorios:</span>
                                <span class="detail-value">₡ ${Number(moratorios).toLocaleString()}</span>
                            </div>
                            ` : ''}
                            <div class="payment-total">
                                <span>Total a Pagar:</span>
                                <span>₡ ${Number(total).toLocaleString()}</span>
                            </div>
                        </div>
                        <div class="payment-actions">
                            <button class="btn btn-secondary" onclick="ocultarPrevisualizacionPago()">Cancelar</button>
                            <button class="btn btn-primary" onclick="procesarPago(${factura.ID}, ${idPropiedad})">Confirmar Pago</button>
                        </div>
                    </div>
                </div>
            `;
            document.getElementById('previsualizacionPago').style.display = 'block';
        } else {
            alert('Error: ' + datos.message);
        }
    } catch (error) {
        alert('Error al cargar previsualización: ' + error.message);
    }
};

window.ocultarPrevisualizacionPago = function() {
    document.getElementById('previsualizacionPago').style.display = 'none';
};

window.procesarXMLOperaciones = async function() {
    const archivoInput = document.getElementById('archivoXML');
    const archivo = archivoInput.files[0];
    
    if (!archivo) {
        alert('Por favor seleccione un archivo XML');
        return;
    }
    
    try {
        const formData = new FormData();
        formData.append('archivo', archivo);
        
        const respuesta = await fetch(`${API_BASE}/procesarXMLOperaciones`, {
            method: 'POST',
            body: formData,
            credentials: 'include'
        });
        
        const datos = await respuesta.json();
        
        if (datos.success) {
            alert('XML procesado exitosamente: ' + datos.message);
            cargarDashboard();
            document.getElementById('archivoXML').value = '';
        } else {
            alert('Error al procesar XML: ' + datos.message);
        }
    } catch (error) {
        alert('Error de conexión: ' + error.message);
    }
};

window.ejecutarProcesoMasivo = async function(proceso) {
    try {
        const respuesta = await fetch(`${API_BASE}/ejecutarProcesoMasivo`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ proceso: proceso }),
            credentials: 'include'
        });
        
        const datos = await respuesta.json();
        
        if (datos.success) {
            alert(`Proceso ${proceso} ejecutado exitosamente`);
            cargarDashboard();
        } else {
            alert('Error al ejecutar proceso: ' + datos.message);
        }
    } catch (error) {
        alert('Error de conexión: ' + error.message);
    }
};

window.procesarPago = async function(idFactura, idPropiedad) {
    try {
        const respuesta = await fetch(`${API_BASE}/confirmarFacturaMasAntigua`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ 
                idFactura: idFactura,
                tipoMedioPago: 1
            }),
            credentials: 'include'
        });
        
        const datos = await respuesta.json();
        
        if (datos.success) {
            alert(`Pago procesado exitosamente\nComprobante: ${datos.comprobante}`);
            document.getElementById('previsualizacionPago').style.display = 'none';
            cargarDashboard();
            mostrarFacturasPropiedad(idPropiedad);
        } else {
            alert('Error al procesar pago: ' + datos.message);
        }
    } catch (error) {
        alert('Error al procesar pago: ' + error.message);
    }
};

document.addEventListener('DOMContentLoaded', async function() {
    try {
        const respuesta = await fetch(`${API_BASE}/verificarSesion`, {
            method: 'GET',
            credentials: 'include'
        });
        
        const datos = await respuesta.json();
        
        if (datos.success && datos.autenticado) {
            document.getElementById('pantallaInicioSesion').style.display = 'none';
            document.getElementById('app').style.display = 'flex';
            document.getElementById('nombreUsuarioDisplay').textContent = datos.userName;
            document.getElementById('avatarUsuario').textContent = datos.userName.charAt(0).toUpperCase();
            cargarDashboard();
        }
    } catch (error) {
        console.error('Error al verificar sesión:', error);
    }
});

window.asociarCCPropiedad = async function() {
    const finca = document.getElementById('busquedaFincaCC').value;
    const idCC = document.getElementById('selectCC').value;
    
    if (!finca || !idCC) {
        alert('Por favor ingrese número de finca y seleccione un concepto de cobro');
        return;
    }
    
    try {
        const respuesta = await fetch(`${API_BASE}/gestionarCCPropiedad`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                numFinca: finca,
                idCC: parseInt(idCC),
                tipoAsociacion: 1
            }),
            credentials: 'include'
        });
        
        const datos = await respuesta.json();
        
        if (datos.success) {
            alert('Concepto de cobro asociado exitosamente');
            document.getElementById('busquedaFincaCC').value = '';
            document.getElementById('selectCC').value = '';
            cargarDashboard();
        } else {
            alert('Error: ' + datos.message);
        }
    } catch (error) {
        alert('Error de conexión: ' + error.message);
    }
};

window.desasociarCCPropiedad = async function() {
    const finca = document.getElementById('busquedaFincaCC').value;
    const idCC = document.getElementById('selectCC').value;
    
    if (!finca || !idCC) {
        alert('Por favor ingrese número de finca y seleccione un concepto de cobro');
        return;
    }
    
    try {
        const respuesta = await fetch(`${API_BASE}/gestionarCCPropiedad`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                numFinca: finca,
                idCC: parseInt(idCC),
                tipoAsociacion: 2
            }),
            credentials: 'include'
        });
        
        const datos = await respuesta.json();
        
        if (datos.success) {
            alert('Concepto de cobro desasociado exitosamente');
            document.getElementById('busquedaFincaCC').value = '';
            document.getElementById('selectCC').value = '';
            cargarDashboard();
        } else {
            alert('Error: ' + datos.message);
        }
    } catch (error) {
        alert('Error de conexión: ' + error.message);
    }
};

// Funciones para Reportes
window.generarReporteFacturasPendientes = async function() {
    const fechaInicio = document.getElementById('fechaInicioFacturas').value;
    const fechaFin = document.getElementById('fechaFinFacturas').value;
    
    if (!fechaInicio || !fechaFin) {
        alert('Por favor seleccione ambas fechas');
        return;
    }
    
    try {
        const respuesta = await fetch(`${API_BASE}/reportes/facturasPendientes`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                fechaInicio: fechaInicio,
                fechaFin: fechaFin
            }),
            credentials: 'include'
        });
        
        const datos = await respuesta.json();
        
        if (datos.success) {
            let tablaHTML = `
                <table class="report-table">
                    <thead>
                        <tr>
                            <th>ID Factura</th>
                            <th>Número Finca</th>
                            <th>Fecha Factura</th>
                            <th>Fecha Límite</th>
                            <th>Total</th>
                            <th>Días Vencida</th>
                        </tr>
                    </thead>
                    <tbody>
            `;
            
            if (datos.reporte && datos.reporte.length > 0) {
                datos.reporte.forEach(fila => {
                    tablaHTML += `
                        <tr>
                            <td>${fila.ID}</td>
                            <td>${fila.NumFinca}</td>
                            <td>${new Date(fila.FechaFactura).toLocaleDateString()}</td>
                            <td>${new Date(fila.FechaLimitePago).toLocaleDateString()}</td>
                            <td>₡ ${Number(fila.TotalPagarFinal).toLocaleString()}</td>
                            <td>${fila.DiasVencida || 0}</td>
                        </tr>
                    `;
                });
            } else {
                tablaHTML += `<tr><td colspan="6" style="text-align: center;">No hay datos para mostrar</td></tr>`;
            }
            
            tablaHTML += '</tbody></table>';
            document.getElementById('resultadoReporteFacturas').innerHTML = tablaHTML;
        } else {
            alert('Error: ' + datos.message);
        }
    } catch (error) {
        alert('Error de conexión: ' + error.message);
    }
};

window.generarReporteRecaudacionCC = async function() {
    const fechaInicio = document.getElementById('fechaInicioRecaudacion').value;
    const fechaFin = document.getElementById('fechaFinRecaudacion').value;
    
    if (!fechaInicio || !fechaFin) {
        alert('Por favor seleccione ambas fechas');
        return;
    }
    
    try {
        const respuesta = await fetch(`${API_BASE}/reportes/recaudacionCC`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                fechaInicio: fechaInicio,
                fechaFin: fechaFin
            }),
            credentials: 'include'
        });
        
        const datos = await respuesta.json();
        
        if (datos.success) {
            let tablaHTML = `
                <table class="report-table">
                    <thead>
                        <tr>
                            <th>Concepto de Cobro</th>
                            <th>Cantidad Pagos</th>
                            <th>Total Recaudado</th>
                        </tr>
                    </thead>
                    <tbody>
            `;
            
            if (datos.reporte && datos.reporte.length > 0) {
                datos.reporte.forEach(fila => {
                    tablaHTML += `
                        <tr>
                            <td>${fila.ConceptoCobro}</td>
                            <td>${fila.CantidadPagos}</td>
                            <td>₡ ${Number(fila.TotalRecaudado).toLocaleString()}</td>
                        </tr>
                    `;
                });
            } else {
                tablaHTML += `<tr><td colspan="3" style="text-align: center;">No hay datos para mostrar</td></tr>`;
            }
            
            tablaHTML += '</tbody></table>';
            document.getElementById('resultadoReporteRecaudacion').innerHTML = tablaHTML;
        } else {
            alert('Error: ' + datos.message);
        }
    } catch (error) {
        alert('Error de conexión: ' + error.message);
    }
};

window.generarReportePropiedadesMorosas = async function() {
    try {
        const respuesta = await fetch(`${API_BASE}/reportes/propiedadesMorosas`, {
            method: 'GET',
            credentials: 'include'
        });
        
        const datos = await respuesta.json();
        
        if (datos.success) {
            let tablaHTML = `
                <table class="report-table">
                    <thead>
                        <tr>
                            <th>Número Finca</th>
                            <th>Propietario</th>
                            <th>Facturas Vencidas</th>
                            <th>Total Adeudado</th>
                            <th>Última Fecha Vencimiento</th>
                        </tr>
                    </thead>
                    <tbody>
            `;
            
            if (datos.reporte && datos.reporte.length > 0) {
                datos.reporte.forEach(fila => {
                    tablaHTML += `
                        <tr>
                            <td>${fila.NumFinca}</td>
                            <td>${fila.Propietario}</td>
                            <td>${fila.FacturasVencidas}</td>
                            <td>₡ ${Number(fila.TotalAdeudado).toLocaleString()}</td>
                            <td>${new Date(fila.FechaVencimientoMasReciente).toLocaleDateString()}</td>
                        </tr>
                    `;
                });
            } else {
                tablaHTML += `<tr><td colspan="5" style="text-align: center;">No hay propiedades morosas</td></tr>`;
            }
            
            tablaHTML += '</tbody></table>';
            document.getElementById('resultadoReporteMorosas').innerHTML = tablaHTML;
        } else {
            alert('Error: ' + datos.message);
        }
    } catch (error) {
        alert('Error de conexión: ' + error.message);
    }
};

window.generarReporteConsumoAgua = async function() {
    const fechaInicio = document.getElementById('fechaInicioConsumo').value;
    const fechaFin = document.getElementById('fechaFinConsumo').value;
    
    if (!fechaInicio || !fechaFin) {
        alert('Por favor seleccione ambas fechas');
        return;
    }
    
    try {
        const respuesta = await fetch(`${API_BASE}/reportes/consumoAgua`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                fechaInicio: fechaInicio,
                fechaFin: fechaFin
            }),
            credentials: 'include'
        });
        
        const datos = await respuesta.json();
        
        if (datos.success) {
            let tablaHTML = `
                <table class="report-table">
                    <thead>
                        <tr>
                            <th>Número Finca</th>
                            <th>Número Medidor</th>
                            <th>Consumo M3</th>
                            <th>Ajustes Crédito</th>
                            <th>Ajustes Débito</th>
                            <th>Saldo Actual</th>
                        </tr>
                    </thead>
                    <tbody>
            `;
            
            if (datos.reporte && datos.reporte.length > 0) {
                datos.reporte.forEach(fila => {
                    tablaHTML += `
                        <tr>
                            <td>${fila.NumFinca}</td>
                            <td>${fila.NumMedidor}</td>
                            <td>${Number(fila.ConsumoM3 || 0).toFixed(2)}</td>
                            <td>${Number(fila.AjustesCreditoM3 || 0).toFixed(2)}</td>
                            <td>${Number(fila.AjustesDebitoM3 || 0).toFixed(2)}</td>
                            <td>${Number(fila.SaldoActual || 0).toFixed(2)}</td>
                        </tr>
                    `;
                });
            } else {
                tablaHTML += `<tr><td colspan="6" style="text-align: center;">No hay datos para mostrar</td></tr>`;
            }
            
            tablaHTML += '</tbody></table>';
            document.getElementById('resultadoReporteConsumo').innerHTML = tablaHTML;
        } else {
            alert('Error: ' + datos.message);
        }
    } catch (error) {
        alert('Error de conexión: ' + error.message);
    }
};

window.generarReporteCortesReconexiones = async function() {
    const fechaInicio = document.getElementById('fechaInicioCortes').value;
    const fechaFin = document.getElementById('fechaFinCortes').value;
    
    if (!fechaInicio || !fechaFin) {
        alert('Por favor seleccione ambas fechas');
        return;
    }
    
    try {
        const respuesta = await fetch(`${API_BASE}/reportes/cortesReconexiones`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                fechaInicio: fechaInicio,
                fechaFin: fechaFin
            }),
            credentials: 'include'
        });
        
        const datos = await respuesta.json();
        
        if (datos.success) {
            let tablaHTML = `
                <table class="report-table">
                    <thead>
                        <tr>
                            <th>Número Finca</th>
                            <th>Fecha Corte</th>
                            <th>Estado Corte</th>
                            <th>Fecha Reconexión</th>
                            <th>Total Factura</th>
                        </tr>
                    </thead>
                    <tbody>
            `;
            
            if (datos.reporte && datos.reporte.length > 0) {
                datos.reporte.forEach(fila => {
                    const estadoCorte = fila.EstadoCorte ? 'Activo' : 'Inactivo';
                    const fechaReconexion = fila.FechaReconexion ? new Date(fila.FechaReconexion).toLocaleDateString() : 'N/A';
                    
                    tablaHTML += `
                        <tr>
                            <td>${fila.NumFinca}</td>
                            <td>${new Date(fila.FechaCorte).toLocaleDateString()}</td>
                            <td>${estadoCorte}</td>
                            <td>${fechaReconexion}</td>
                            <td>₡ ${Number(fila.TotalPagarFinal).toLocaleString()}</td>
                        </tr>
                    `;
                });
            } else {
                tablaHTML += `<tr><td colspan="5" style="text-align: center;">No hay datos para mostrar</td></tr>`;
            }
            
            tablaHTML += '</tbody></table>';
            document.getElementById('resultadoReporteCortes').innerHTML = tablaHTML;
        } else {
            alert('Error: ' + datos.message);
        }
    } catch (error) {
        alert('Error de conexión: ' + error.message);
    }
};

window.generarReporteEstadisticasPagos = async function() {
    const meses = document.getElementById('mesesEstadisticas').value;
    
    try {
        const respuesta = await fetch(`${API_BASE}/reportes/estadisticasPagos`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                meses: parseInt(meses)
            }),
            credentials: 'include'
        });
        
        const datos = await respuesta.json();
        
        if (datos.success) {
            let tablaHTML = `
                <table class="report-table">
                    <thead>
                        <tr>
                            <th>Año</th>
                            <th>Mes</th>
                            <th>Total Facturas</th>
                            <th>Total Recaudado</th>
                            <th>Promedio Factura</th>
                        </tr>
                    </thead>
                    <tbody>
            `;
            
            if (datos.reporte && datos.reporte.length > 0) {
                datos.reporte.forEach(fila => {
                    const nombreMes = new Date(fila.Año, fila.Mes - 1).toLocaleString('es', { month: 'long' });
                    
                    tablaHTML += `
                        <tr>
                            <td>${fila.Año}</td>
                            <td>${nombreMes.charAt(0).toUpperCase() + nombreMes.slice(1)}</td>
                            <td>${fila.TotalFacturas}</td>
                            <td>₡ ${Number(fila.TotalRecaudado).toLocaleString()}</td>
                            <td>₡ ${Number(fila.PromedioFactura).toLocaleString()}</td>
                        </tr>
                    `;
                });
            } else {
                tablaHTML += `<tr><td colspan="5" style="text-align: center;">No hay datos para mostrar</td></tr>`;
            }
            
            tablaHTML += '</tbody></table>';
            document.getElementById('resultadoReporteEstadisticas').innerHTML = tablaHTML;
        } else {
            alert('Error: ' + datos.message);
        }
    } catch (error) {
        alert('Error de conexión: ' + error.message);
    }
};

window.cargarConfiguracion = async function() {
    try {
        const respuesta = await fetch(`${API_BASE}/configuracion/obtenerParametros`, {
            method: 'GET',
            credentials: 'include'
        });
        
        const datos = await respuesta.json();
        
        if (datos.success) {
            datos.parametros.forEach(parametro => {
                const elemento = document.getElementById(parametro.Nombre);
                if (elemento) {
                    elemento.value = parametro.Valor;
                }
            });
        } else {
            console.error('Error al cargar configuración:', datos.message);
        }
    } catch (error) {
        console.error('Error al cargar configuración:', error);
    }
};

window.actualizarParametro = async function(nombreParametro) {
    const valor = document.getElementById(nombreParametro).value;
    
    if (!valor) {
        alert('Por favor ingrese un valor válido');
        return;
    }
    
    try {
        const respuesta = await fetch(`${API_BASE}/configuracion/actualizarParametro`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                nombre: nombreParametro,
                valor: valor
            }),
            credentials: 'include'
        });
        
        const datos = await respuesta.json();
        
        if (datos.success) {
            alert('Parámetro actualizado exitosamente');
            cargarDashboard(); // Actualizar estadísticas si es necesario
        } else {
            alert('Error: ' + datos.message);
        }
    } catch (error) {
        alert('Error de conexión: ' + error.message);
    }
};

window.buscarUsuarios = async function() {
    const busqueda = document.getElementById('buscarUsuario').value;
    
    if (!busqueda) {
        alert('Por favor ingrese un término de búsqueda');
        return;
    }
    
    try {
        const respuesta = await fetch(`${API_BASE}/configuracion/buscarUsuarios`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                busqueda: busqueda
            }),
            credentials: 'include'
        });
        
        const datos = await respuesta.json();
        
        if (datos.success) {
            let usuariosHTML = '';
            
            if (datos.usuarios && datos.usuarios.length > 0) {
                datos.usuarios.forEach(usuario => {
                    usuariosHTML += `
                        <div class="invoice-item">
                            <div class="invoice-icon">
                                <i class="fas fa-user"></i>
                            </div>
                            <div class="invoice-details">
                                <div class="invoice-number">${usuario.Nombre}</div>
                                <div class="invoice-date">${usuario.ValorDocumentoId} • ${usuario.EsActivo ? 'Activo' : 'Inactivo'}</div>
                            </div>
                            <div class="invoice-actions">
                                <button class="btn btn-secondary btn-sm" onclick="cambiarEstadoUsuario(${usuario.ID}, ${!usuario.EsActivo})">
                                    ${usuario.EsActivo ? 'Desactivar' : 'Activar'}
                                </button>
                            </div>
                        </div>
                    `;
                });
            } else {
                usuariosHTML = '<p>No se encontraron usuarios</p>';
            }
            
            document.getElementById('resultadosUsuarios').innerHTML = usuariosHTML;
        } else {
            alert('Error: ' + datos.message);
        }
    } catch (error) {
        alert('Error de conexión: ' + error.message);
    }
};

window.cambiarEstadoUsuario = async function(idUsuario, nuevoEstado) {
    try {
        const respuesta = await fetch(`${API_BASE}/configuracion/cambiarEstadoUsuario`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                idUsuario: idUsuario,
                nuevoEstado: nuevoEstado
            }),
            credentials: 'include'
        });
        
        const datos = await respuesta.json();
        
        if (datos.success) {
            alert('Estado de usuario actualizado exitosamente');
            buscarUsuarios(); // Recargar la lista
        } else {
            alert('Error: ' + datos.message);
        }
    } catch (error) {
        alert('Error de conexión: ' + error.message);
    }
};

window.ejecutarRespaldo = async function() {
    if (!confirm('¿Está seguro de que desea generar un respaldo de la base de datos?')) {
        return;
    }
    
    try {
        const respuesta = await fetch(`${API_BASE}/configuracion/ejecutarRespaldo`, {
            method: 'POST',
            credentials: 'include'
        });
        
        const datos = await respuesta.json();
        
        if (datos.success) {
            alert('Respaldo generado exitosamente: ' + datos.archivo);
        } else {
            alert('Error: ' + datos.message);
        }
    } catch (error) {
        alert('Error de conexión: ' + error.message);
    }
};

window.limpiarCache = async function() {
    if (!confirm('¿Está seguro de que desea limpiar la cache del sistema?')) {
        return;
    }
    
    try {
        const respuesta = await fetch(`${API_BASE}/configuracion/limpiarCache`, {
            method: 'POST',
            credentials: 'include'
        });
        
        const datos = await respuesta.json();
        
        if (datos.success) {
            alert('Cache limpiada exitosamente');
        } else {
            alert('Error: ' + datos.message);
        }
    } catch (error) {
        alert('Error de conexión: ' + error.message);
    }
};

window.reiniciarContadores = async function() {
    if (!confirm('¿Está seguro de que desea reiniciar los contadores del sistema? Esta acción no se puede deshacer.')) {
        return;
    }
    
    try {
        const respuesta = await fetch(`${API_BASE}/configuracion/reiniciarContadores`, {
            method: 'POST',
            credentials: 'include'
        });
        
        const datos = await respuesta.json();
        
        if (datos.success) {
            alert('Contadores reiniciados exitosamente');
            cargarDashboard();
        } else {
            alert('Error: ' + datos.message);
        }
    } catch (error) {
        alert('Error de conexión: ' + error.message);
    }
};

document.querySelector('[data-section="settings"]').addEventListener('click', function() {
    setTimeout(() => {
        cargarConfiguracion();
    }, 100);
});