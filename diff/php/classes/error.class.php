<?php
class Error {
    
    public $enableErrorPrint    =   1;
    public $showErrorPage       =   false;
    public $errorString;
    
    public function setDebug($switch = 0){
        $this->enableErrorPrint =   $switch ?   1 : 0; 
    }
    
    public function setError($string = false, $file = 0, $line = 0){
        if(!$string || !$file || !$line){
            return;
        }
        throw new Exception('<b>File</b> '.$file.', <b>Line</b> '.$line.': '.$string);
    }
    
    public function showError($error){
        if($this->enableErrorPrint){
            echo $error->getMessage();
        }
        $this->errorString      =   $error->getMessage();
        $this->showErrorPage    =   true;
        exit;
    }
    
}
?>