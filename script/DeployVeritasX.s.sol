// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/VeritasX.sol";

contract DeployVeritasX is Script {

    function run() external {
        // --- Configuración ---
        // Intenta leer como bytes32 (espera el string SIN 0x)
        bytes32 pkBytes32 = vm.envBytes32("PRIVATE_KEY");

        // Convierte bytes32 a uint256 para startBroadcast
        uint256 deployerPrivateKey = uint256(pkBytes32);

        // Verifica que leyó algo (opcional)
        console.logBytes32(pkBytes32); // Imprime los bytes leídos

        // --- Lógica de Despliegue ---
        console.log("Deploying VeritasX...");

        vm.startBroadcast(deployerPrivateKey); // Usa la clave convertida

        // Crear una nueva instancia de VeritasX (sin argumentos de constructor ya que los refactorizamos)
        VeritasX veritasX = new VeritasX();

        vm.stopBroadcast();

        console.log("VeritasX deployed to:", address(veritasX));
    }
}
