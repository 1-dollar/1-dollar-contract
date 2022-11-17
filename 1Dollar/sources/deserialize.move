module oneDollar_v0_0::deserialize{

    use std::error;

    use std::vector as vector;
    


    public fun deserialize_vector_u64(vec: &vector<u8>) : vector<u64>{
        let bytes_len = vector::length(vec);
        assert!(bytes_len >0,error::invalid_argument(0));
        let length = ((*vector::borrow(vec,0)) as u64);
        assert!(length*8  == bytes_len-1,error::invalid_argument(1));
        let result_vector = vector::empty();

        let index = 0;
        while(index < length){
            let x = ((*vector::borrow(vec, 1+index*8) as u64) << 7) + ((*vector::borrow(vec, 2+index*8) as u64) << 6)
            + ((*vector::borrow(vec, 3+index*8) as u64) << 5) + ((*vector::borrow(vec, 4+index*8) as u64) << 4)
            + ((*vector::borrow(vec, 5+index*8) as u64) << 3) + ((*vector::borrow(vec, 6+index*8) as u64) << 2)
            + ((*vector::borrow(vec, 7+index*8) as u64) << 1) + (*vector::borrow(vec, 8+index*8) as u64);
            vector::push_back(&mut result_vector,x);
        };
        result_vector
    }
    
    public fun deserialize_vector_u64_u64(vec: &vector<u8>): vector<vector<u64>>{
        let bytes_len = vector::length(vec);
        assert!(bytes_len >0,error::invalid_argument(0));
        //let length = ((*vector::borrow(vec,0)) as u64);
        let result_vector = vector::empty();
        let outside_index = 1;
        while(outside_index < bytes_len){
            let vec_item_len = ((*vector::borrow(vec,outside_index)) as u64);
            let result_item = vector::empty<u64>();
            let inside_index = 0;
            while(inside_index < vec_item_len){
                let x = ((*vector::borrow(vec, outside_index+1+inside_index*8) as u64) << 7) + ((*vector::borrow(vec, outside_index+2+inside_index*8) as u64) << 6)
                    + ((*vector::borrow(vec, outside_index+3+inside_index*8) as u64) << 5) + ((*vector::borrow(vec, outside_index+4+inside_index*8) as u64) << 4)
                    + ((*vector::borrow(vec, outside_index+5+inside_index*8) as u64) << 3) + ((*vector::borrow(vec, outside_index+6+inside_index*8) as u64) << 2)
                    + ((*vector::borrow(vec, outside_index+7+inside_index*8) as u64) << 1) + (*vector::borrow(vec, outside_index+8+inside_index*8) as u64);
                vector::push_back(&mut result_item,x);
            };
            outside_index = outside_index+1+vec_item_len*8;
            vector::push_back(&mut result_vector,result_item);
        };
        result_vector
    }


}