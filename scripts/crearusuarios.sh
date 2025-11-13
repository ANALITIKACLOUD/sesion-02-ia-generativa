#!/bin/bash

# Script para crear usuarios IAM en AWS CloudShell
# Crea grupo, usuarios, contraseñas y asigna permisos de administrador

# Contraseña por defecto para todos los usuarios
PASSWORD_DEFAULT="Participante2025!"

echo "=== Creando grupo de participantes ==="

# Crear el grupo
aws iam create-group --group-name participantes
echo "✓ Grupo 'participantes' creado"

# Adjuntar política de AdministratorAccess al grupo
aws iam attach-group-policy \
    --group-name participantes \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
echo "✓ Política AdministratorAccess adjuntada al grupo"

echo ""
echo "=== Creando usuarios con contraseñas ==="
echo "Contraseña por defecto: $PASSWORD_DEFAULT"
echo ""

# Array de usuarios (username:nombre_completo)
usuarios=(
    "alexis.almeyda:Alexis Yair Almeyda Napa"
    "alpina.echevarria:Alpina Amparo Echevarría Quintana"
    "araceli.cueva:Araceli Yoselin Cueva Sánchez"
    "billy.polo:Billy Polo Torres"
    "breiner.correa:Breiner Roiser Correa Benites"
    "camila.falcon:Camila Jasmin Falcon Cordova"
    "christian.carranza:Christian Bernardo Carranza Vergara"
    "delsy.banda:Delsy Banda Vargas"
    "ditxon.milan:Ditxon Gabriel Milan Jara"
    "eduardo.barron:Eduardo Ciro Barron Lopez"
    "frank.diaz:Frank Diaz Soto"
    "genaro.martinez:Genaro Alfredo Martinez Medina"
    "genesis.fernandez:Genesis Maria Fernandez Sifuentes"
    "geraldine.curipaco:Geraldine Nisbeth Curipaco Huayllani"
    "hector.quispe:Hector Alvaro Quispe Abanto"
    "jahn.bedon:Jahn Jhordee Bedon Romero"
    "jeronimo.enciso:Jeronimo Yoel Enciso Saravia"
    "jhennyfer.zarate:Jhennyfer Nayeli Zarate Villar"
    "jhoel.lucero:Jhoel Hugo Lucero Herrera"
    "jose.huapaya:Jose Alberto Huapaya Vasquez"
    "jose.reveron:Jose Gregorio Reveron Garcia"
    "jose.julca:Jose Luis Julca Huarca"
    "julio.gomez:Julio Fernando Gomez Ccorahua"
    "kattya.garcia:Kattya Isabel Garcia Velasquez"
    "liz.quiroz:Liz Fiorella Quiroz Sotelo"
    "lizell.condori:Lizell Nieves Condori Cabana"
    "luis.mendoza:Luis Arturo Mendoza Luna"
    "manuel.ochoa:Manuel Alejandro Ochoa Bolaños"
    "marianella.caycho:Marianella Del Carmen Caycho Herrera"
    "maricielo.nestares:Maricielo Abigail Nestares Flores"
    "miguel.ventocilla:Miguel Antonio Ventocilla Tuesta"
    "monica.rantes:Monica Tahiz Rantes Garcia"
    "nataly.vasquez:Nataly Grace Vasquez Saenz"
    "nicolle.acosta:Nicolle Acosta Huarcaya"
    "omar.quesquen:Omar Ernesto Quesquen Terrones"
    "renzo.portocarrero:Renzo Orlando Portocarrero Vargas"
    "sebastian.alvaro:Sebastian Alvaro Del Castillo"
    "victor.ramirez:Víctor Angel Ramírez Ramírez"
    "artemio.perlacios:Artemio Harold Perlacios Luque"
    "braulio.molleapaza:Braulio Molleapaza"
    "jose.alegre:Jose Alegre"
    "rodrigo.loaiza:Rodrigo Loaiza"
    "gianella.neira:Gianella Neira"
)

# Crear cada usuario, agregar al grupo y crear contraseña
contador=0
for usuario_info in "${usuarios[@]}"; do
    username=$(echo $usuario_info | cut -d':' -f1)
    nombre_completo=$(echo $usuario_info | cut -d':' -f2)
    
    # Crear usuario
    aws iam create-user --user-name "$username" --tags Key=Name,Value="$nombre_completo" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✓ Usuario creado: $username ($nombre_completo)"
        
        # Agregar usuario al grupo
        aws iam add-user-to-group --user-name "$username" --group-name participantes
        
        # Crear perfil de login con contraseña (sin requerir cambio)
        aws iam create-login-profile \
            --user-name "$username" \
            --password "$PASSWORD_DEFAULT" \
            --no-password-reset-required 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo "  ✓ Contraseña configurada"
        else
            echo "  ✗ Error al configurar contraseña (posiblemente ya existe)"
        fi
        
        contador=$((contador + 1))
    else
        echo "✗ Error al crear: $username (posiblemente ya existe)"
    fi
    echo ""
done

echo ""
echo "=== Resumen ==="
echo "Total de usuarios procesados: $contador"
echo "Grupo: participantes"
echo "Permisos: AdministratorAccess"
echo "Contraseña por defecto: $PASSWORD_DEFAULT"
echo ""
echo "=== Información de acceso ==="
echo "Los usuarios pueden iniciar sesión en:"
echo "https://$(aws sts get-caller-identity --query Account --output text).signin.aws.amazon.com/console"
echo ""
echo "Usuario: [nombre_usuario]"
echo "Contraseña: $PASSWORD_DEFAULT"
echo ""
echo "Nota: La contraseña NO requiere cambio obligatorio"