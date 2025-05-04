// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/CollaborativeCanvas.sol";

contract CanvasTest is Test {
    CollaborativeCanvas canvas;
    address deployer = makeAddr("deployer");

    function setUp() public {
        // Conectar al contrato existente
        canvas = CollaborativeCanvas(0x76b595369AC78435a6a42B1D59aC820A9E185B54);

        // Enviar ETH al deployer para pagar gas
        vm.deal(deployer, 1 ether);
    }

    function testDimensions() public {
        // Verificar dimensiones
        assertEq(canvas.canvasWidth(), 32, "Canvas width should be 32");
        assertEq(canvas.canvasHeight(), 32, "Canvas height should be 32");
    }

    function testSetPixelGas() public {
        // Establecer parametros
        uint x = 5;
        uint y = 10;
        string memory color = "#FF0000";

        vm.startPrank(deployer);

        // Medir gas
        uint startGas = gasleft();
        canvas.setPixel(x, y, color);
        uint gasUsed = startGas - gasleft();

        // Imprimir resultado
        console.log("Gas usado en setPixel:", gasUsed);

        // Verificar pixel
        (address owner, string memory pixelColor, ) = canvas.getPixel(x, y);
        assertEq(owner, deployer, "Owner should be deployer");
        assertEq(pixelColor, color, "Color should match");

        vm.stopPrank();
    }

    function testUpdateSamePixelMultipleTimes() public {
        // Configurar pixel
        uint x = 15;
        uint y = 20;
        string[3] memory colors = ["#FF0000", "#00FF00", "#0000FF"];

        vm.startPrank(deployer);

        uint lastGasUsed;

        for (uint i = 0; i < colors.length; i++) {
            // Medir gas
            uint startGas = gasleft();
            canvas.setPixel(x, y, colors[i]);
            uint gasUsed = startGas - gasleft();

            // Imprimir resultado
            console.log("Actualizacion", i+1, "Gas usado:", gasUsed);

            // Comparar con anterior
            if (i > 0) {
                int diff = int(gasUsed) - int(lastGasUsed);
                console.log("Diferencia con anterior:", diff);
            }

            lastGasUsed = gasUsed;

            // Verificar
            (,string memory pixelColor,) = canvas.getPixel(x, y);
            assertEq(pixelColor, colors[i], "Color should match");
        }

        vm.stopPrank();
    }

    function testCompareNewVsExistingPixel() public {
        // Parametros
        uint newX = 25;
        uint newY = 25;
        uint existingX = 15;
        uint existingY = 20;
        string memory color = "#AABBCC";

        vm.startPrank(deployer);

        // Medir gas para nuevo pixel
        uint startGas = gasleft();
        canvas.setPixel(newX, newY, color);
        uint newPixelGas = startGas - gasleft();
        console.log("Gas para nuevo pixel:", newPixelGas);

        // Medir gas para pixel existente
        startGas = gasleft();
        canvas.setPixel(existingX, existingY, color);
        uint existingPixelGas = startGas - gasleft();
        console.log("Gas para pixel existente:", existingPixelGas);

        // Calcular diferencia
        int diff = int(newPixelGas) - int(existingPixelGas);
        console.log("Diferencia (nuevo - existente):", diff);

        // Calcular porcentaje
        if (newPixelGas > 0) {
            uint percentage = 100 - (existingPixelGas * 100 / newPixelGas);
            console.log("Porcentaje de ahorro:", percentage, "%");
        }

        vm.stopPrank();
    }

    function testMantleVsEthereumGasCost() public {
        // Valores estimados
        uint avgGasPerSetPixel = 70000;
        uint mantleGasPrice = 20000000; // 0.02 gwei
        uint ethereumGasPrice = 20000000000; // 20 gwei

        // Calcular costos
        uint txCount = 1000;
        uint ethCost = avgGasPerSetPixel * ethereumGasPrice * txCount;
        uint mantleCost = avgGasPerSetPixel * mantleGasPrice * txCount;

        // Mostrar resultados
        console.log("Costo estimado en Ethereum (wei):", ethCost);
        console.log("Costo real en Mantle (wei):", mantleCost);
        console.log("Ahorro (wei):", ethCost - mantleCost);

        // Porcentaje
        uint percentage = 100 - (mantleCost * 100 / ethCost);
        console.log("Porcentaje de ahorro:", percentage, "%");
    }
}
