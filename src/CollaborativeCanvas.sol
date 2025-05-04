// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title CollaborativeCanvas
 * @dev Un contrato para un lienzo de píxeles colaborativo on-chain.
 * Demuestra un caso de uso viable en L2 (como Mantle) debido a los bajos costos
 * de transacción para actualizaciones frecuentes de estado (cambiar píxeles).
 */
contract CollaborativeCanvas {

    struct Pixel {
        address owner;
        string color; // Usamos string para flexibilidad (ej: "#FF0000", "blue")
        uint256 lastUpdateTimestamp;
    }

    uint256 public immutable canvasWidth;
    uint256 public immutable canvasHeight;

    // Mapeo para almacenar los datos de cada píxel: x => y => PixelData
    mapping(uint256 => mapping(uint256 => Pixel)) public pixels;

    event PixelSet(
        uint256 indexed x,
        uint256 indexed y,
        address indexed setter,
        string color,
        uint256 timestamp
    );

    /**
     * @dev Constructor para inicializar las dimensiones del lienzo.
     * @param _width Ancho del lienzo.
     * @param _height Alto del lienzo.
     */
    constructor(uint256 _width, uint256 _height) {
        require(_width > 0 && _height > 0, "Canvas dimensions must be positive");
        canvasWidth = _width;
        canvasHeight = _height;
    }

    /**
     * @dev Permite a cualquier usuario establecer el color de un píxel específico.
     * Esta es la función principal cuya ejecución frecuente es costosa en L1 pero barata en L2.
     * @param _x Coordenada X del píxel (0 a canvasWidth - 1).
     * @param _y Coordenada Y del píxel (0 a canvasHeight - 1).
     * @param _color El nuevo color para el píxel (como string).
     */
    function setPixel(uint256 _x, uint256 _y, string memory _color) public {
        require(_x < canvasWidth, "X coordinate out of bounds");
        require(_y < canvasHeight, "Y coordinate out of bounds");
        // Podríamos añadir validación de color aquí si quisiéramos ser más estrictos (ej. longitud, formato)
        require(bytes(_color).length > 0 && bytes(_color).length < 32, "Invalid color string"); // Validación simple

        Pixel storage currentPixel = pixels[_x][_y];
        currentPixel.owner = msg.sender;
        currentPixel.color = _color;
        currentPixel.lastUpdateTimestamp = block.timestamp;

        emit PixelSet(_x, _y, msg.sender, _color, block.timestamp);
    }

    /**
     * @dev Obtiene los datos de un píxel específico.
     * @param _x Coordenada X.
     * @param _y Coordenada Y.
     * @return owner La dirección del último usuario que modificó el píxel.
     * @return color El color actual del píxel.
     * @return lastUpdateTimestamp El timestamp de la última modificación.
     */
    function getPixel(uint256 _x, uint256 _y)
        public
        view
        returns (address owner, string memory color, uint256 lastUpdateTimestamp)
    {
        require(_x < canvasWidth, "X coordinate out of bounds");
        require(_y < canvasHeight, "Y coordinate out of bounds");

        Pixel storage p = pixels[_x][_y];
        // Devolver valores por defecto si el píxel nunca se ha establecido
        // El owner será 0x0 por defecto, color string vacío "", timestamp 0
        return (p.owner, p.color, p.lastUpdateTimestamp);
    }
}
