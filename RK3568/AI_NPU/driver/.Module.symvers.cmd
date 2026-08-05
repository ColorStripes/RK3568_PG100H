cmd_/userdata/AI_NPU/driver/Module.symvers :=  sed 's/ko$$/o/'  /userdata/AI_NPU/driver/modules.order | scripts/mod/modpost      -o /userdata/AI_NPU/driver/Module.symvers -e -i Module.symvers -T - 
