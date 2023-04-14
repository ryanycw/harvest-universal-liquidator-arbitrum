// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// imported contracts and libraries
import "@openzeppelin/contracts/access/Ownable.sol";

// interfaces
import "../interface/IUniversalLiquidatorRegistry.sol";

// librarise
import "../libraries/DataTypes.sol";
import "../libraries/Errors.sol";

// constants and types
import {ULRegistryStorage} from "./storage/Storage.sol";

contract UniversalLiquidatorRegistry is
    Ownable,
    IUniversalLiquidatorRegistry,
    ULRegistryStorage
{
    function getPath(
        address _sellToken,
        address _buyToken
    ) public view override returns (DataTypes.SwapInfo[] memory) {
        if (paths[_sellToken][_buyToken].dex != bytes32(0)) {
            DataTypes.SwapInfo[] memory retPaths = new DataTypes.SwapInfo[](1);
            retPaths[0] = DataTypes.SwapInfo(
                dexesInfo[paths[_sellToken][_buyToken].dex],
                paths[_sellToken][_buyToken].paths
            );
            return retPaths;
        }

        for (uint256 idx; idx < intermediateTokens.length; ) {
            if (
                paths[_sellToken][intermediateTokens[idx]].dex != bytes32(0) &&
                paths[intermediateTokens[idx]][_buyToken].dex != bytes32(0)
            ) {
                // found the intermediateToken and intermediateDex
                DataTypes.SwapInfo[] memory retPaths = new DataTypes.SwapInfo[](
                    2
                );
                retPaths[0] = DataTypes.SwapInfo(
                    dexesInfo[paths[_sellToken][intermediateTokens[idx]].dex],
                    paths[_sellToken][intermediateTokens[idx]].paths
                );
                retPaths[1] = DataTypes.SwapInfo(
                    dexesInfo[paths[intermediateTokens[idx]][_buyToken].dex],
                    paths[intermediateTokens[idx]][_buyToken].paths
                );
                return retPaths;
            }
            unchecked {
                ++idx;
            }
        }
        revert("Liquidation path is not set");
    }

    function setPath(
        address _sellToken,
        address _buyToken,
        bytes32 _dex,
        address[] memory _paths
    ) external override onlyOwner {
        // path could also be an empty array
        if (_sellToken != _paths[0]) revert Errors.InvalidPathsStart();
        if (_buyToken != _paths[_paths.length - 1])
            revert Errors.InvalidPathsEnd();

        // path can also be empty
        paths[_sellToken][_buyToken] = DataTypes.PathInfo(_dex, _paths);
    }

    function addIntermediateToken(address _token) public override onlyOwner {
        intermediateTokens.push(_token);
    }

    function addDex(bytes32 _name, address _dex) public override onlyOwner {
        if (_dexExists(_name)) revert Errors.DexExists();
        dexesInfo[_name] = _dex;
        allDexes.push(_name);
    }

    function changeDexAddress(
        bytes32 _name,
        address _dex
    ) public override onlyOwner {
        if (!_dexExists(_name)) revert Errors.DexDoesNotExist();
        dexesInfo[_name] = _dex;
    }

    function getAllDexes() public view override returns (bytes32[] memory) {
        uint256 totalDexes = 0;

        for (uint256 idx = 0; idx < allDexes.length; idx++) {
            if (dexesInfo[allDexes[idx]] != address(0)) {
                totalDexes++;
            }
            unchecked {
                ++idx;
            }
        }

        bytes32[] memory retDexes = new bytes32[](totalDexes);
        uint256 retIdx = 0;

        for (uint256 idx; idx < allDexes.length; ) {
            if (dexesInfo[allDexes[idx]] != address(0)) {
                retDexes[retIdx] = allDexes[idx];
                retIdx++;
            }
            unchecked {
                ++idx;
            }
        }

        return retDexes;
    }

    function _dexExists(bytes32 _name) internal view returns (bool) {
        return dexesInfo[_name] != address(0);
    }
}
