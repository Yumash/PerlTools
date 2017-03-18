<?php
if(!class_exists('Error')){
    die();
}
require_once 'MDB2.php';

class DB extends Error{
    
    private $dsn = array(
            'phptype'  => 'mysql',
            'username' => 'common',
            'password' => 'wAs8VCsPwENwnMcQ',
            'hostspec' => 'localhost',
            'database' => 'gdedomen_ru',
    );
    protected $db;
    
    function connect(){
        try {
            $this->db =& MDB2::connect($this->dsn);
            if (PEAR::isError($this->db)) {
                $this->setError($this->db->getMessage());
            }
            $this->db->query("SET NAMES UTF8");
        }
        catch (Exception $e) {
            $this->showError($e);
        }
    }
    
    function query(){
        try {
            if(!$this->db){
                $this->connect();
            }
            $return                     =   array();
            list($query, $query_data)   =   $this->parseFuncArgs(func_get_args());
            $query_type                 =   array_shift($query_data);
            if(!is_scalar($query_type) || !preg_match('/^array|hash$/i', $query_type)){
                array_unshift($query_data, $query_type);
                $query_type = 'array';
            }
            
            if(!$query){
                $this->setError('Empty query', __FILE__, __LINE__);
            }
            if($query_type == 'array'){
                $this->db->setFetchMode(MDB2_FETCHMODE_ORDERED);
            }
            else {
                $this->db->setFetchMode(MDB2_FETCHMODE_ASSOC);
            }
            if(count($query_data) != 0){
                $sth = $this->db->prepare($query, array_keys($query_data));
                if (PEAR::isError($sth)) {
                    $this->setError('Bad preparing - '.$sth->getMessage(),__FILE__,__LINE__);
                }
                $result = $sth->execute(array_values($query_data));
                $sth->free();
            }
            else{
                $result =& $this->db->query($query)
                    || $this->setError('Bad query: ['.$query.'] '.$this->db->error, __FILE__, __LINE__);
            }
            return $result;

        }
        catch (Exception $e){
            $this->showError($e);
        }
    }
    
    function fetchHash($query){
        try {
            list($query, $query_data) = $this->parseFuncArgs(func_get_args());
            if(!$query){
                $this->setError("No query", __FILE__,__LINE__);
            }
            if(!($result = $this->query($query, 'hash', $query_data))){
                $this->setError("Query failed - ".$query." - ".$this->db->error, __FILE__,__LINE__);
            }
            
            $results = array();
            while ($row = $result->fetchRow()) {
                $results[] = $row;
            }
            return $results;
        }
        catch (Exception $e){
            $this->showError($e);
        }
    }
    function fetchHashRow($query){
        try {
            list($query, $query_data) = $this->parseFuncArgs(func_get_args());
            
            if(!$query){
                $this->setError("No query", __FILE__,__LINE__);
            }
            if(!($result = $this->query($query, 'hash', $query_data))){
                $this->setError("Query failed - ".$query." - ".$this->db->error, __FILE__,__LINE__);
            }
            if(!is_object($result)){
                $this->setError("Query failed - result is not an object", __FILE__,__LINE__);
            }
            return $result->fetchRow();
        }
        catch (Exception $e){
            $this->showError($e);
        }
    }
    
    function fetchArray($query){
        try {
            list($query, $query_data) = $this->parseFuncArgs(func_get_args());
            
            if(!$query){
                $this->setError("No query", __FILE__,__LINE__);
            }
            if(!($result = $this->query($query, 'array', $query_data))){
                $this->setError("Query failed - ".$query." - ".$this->db->error, __FILE__,__LINE__);
            }
            $results = array();
            while ($row = $result->fetchRow()) {
                $results[] = $row;
            }
            return $results;
        }
        catch (Exception $e){
            $this->showError($e);
        }
    }
    function fetchArrayRow($query){
        try {
            list($query, $query_data) = $this->parseFuncArgs(func_get_args());
            
            if(!$query){
                $this->setError("No query", __FILE__,__LINE__);
            }
            if(!($result = $this->query($query, 'array', $query_data))){
                $this->setError("Query failed - ".$query." - ".$this->db->error, __FILE__,__LINE__);
            }
            if(!is_object($result)){
                $this->setError("Query failed - result is not an object", __FILE__,__LINE__);
            }
            return $result->fetchRow();
        }
        catch (Exception $e){
            $this->showError($e);
        }
    }
    
    function parseFuncArgs(){
        try {
            $args = func_get_args();
            $args = $args[0];
            $query = array_shift($args);
            if(!is_array($args)){
                $this->setError("Args are not array", __FILE__, __LINE__);
            }
            $query_data = array();
            if(isset($args[1]) && is_array($args[1])){
                $query_data[] = array_shift($args);
                $args = $args[0];
            }
            foreach($args as $k=>$v){
                if(is_numeric($k) || !isset($this->query_types[$k])){
                    $k  =   gettype($v) == 'integer' ?   'integer'   :   'text';
                }
                $query_data[$k] = $v;
            }
            return array($query, $query_data);
        }
        catch (Exception $e){
            $this->showError($e);
        }
    }
    
}
?>