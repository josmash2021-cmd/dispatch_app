#!/usr/bin/env python3
"""
Crear icono de Dispatch App con fondo BLANCO
El icono original tiene fondo negro, este script lo cambia a blanco.
"""

from PIL import Image
import os

def create_dispatch_icon():
    # Rutas
    base_path = r"C:\Users\Puma\CascadeProjects\dispatch_app\dispatch_app-master\assets"
    input_path = os.path.join(base_path, "launcher_icon.png")
    output_path = os.path.join(base_path, "launcher_icon_white.png")
    foreground_path = os.path.join(base_path, "launcher_icon_foreground.png")
    
    # Cargar imagen original
    img = Image.open(input_path).convert("RGBA")
    
    # Crear fondo blanco
    white_bg = Image.new("RGBA", img.size, (255, 255, 255, 255))
    
    # Separar el carrito del fondo negro
    # El carrito es dorado/amarrillo, el fondo es negro
    datas = img.getdata()
    new_data = []
    
    for item in datas:
        r, g, b, a = item
        # Detectar color negro o muy oscuro (fondo)
        if r < 50 and g < 50 and b < 50:
            # Reemplazar con blanco
            new_data.append((255, 255, 255, 255))
        else:
            # Mantener el color original (carrito dorado)
            new_data.append((r, g, b, a))
    
    # Crear nueva imagen con datos modificados
    new_img = Image.new("RGBA", img.size)
    new_img.putdata(new_data)
    
    # Guardar
    new_img.save(output_path, "PNG")
    print(f"[OK] Icono con fondo blanco creado: {output_path}")
    
    # También crear el foreground si no existe
    if not os.path.exists(foreground_path):
        # Para el foreground, necesitamos solo el carrito sin fondo
        fg_data = []
        for item in datas:
            r, g, b, a = item
            # Detectar color negro o muy oscuro (hacer transparente)
            if r < 50 and g < 50 and b < 50:
                fg_data.append((0, 0, 0, 0))  # Transparente
            else:
                fg_data.append((r, g, b, a))  # Mantener color
        
        fg_img = Image.new("RGBA", img.size)
        fg_img.putdata(fg_data)
        fg_img.save(foreground_path, "PNG")
        print(f"[OK] Foreground creado: {foreground_path}")

if __name__ == "__main__":
    try:
        from PIL import Image
        create_dispatch_icon()
    except ImportError:
        print("[ERROR] Pillow no instalado")
        print("Ejecuta: python -m pip install Pillow")
        exit(1)
