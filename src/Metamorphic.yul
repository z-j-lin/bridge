object "constructor" {
    code {
        //call the factory call back to get the tempAddr
        pop(staticcall(gas(), caller(), msize(), msize(), msize(), msize()))
        returndatacopy(msize(), msize(), returndatasize())
        //delegatecall the temp contract to hit the init code 
        pop(delegatecall(gas(), mload(callvalue()), callvalue(), callvalue(), callvalue(), callvalue()))
        returndatacopy(callvalue(), callvalue(), returndatasize())
        return(callvalue(), returndatasize())
    }
    object "runtime" {
        code {}
    }
}
// 0x59595959335afa503d59593e3434343434515af4503d34343e3d34f3fe