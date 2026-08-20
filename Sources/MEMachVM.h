#ifndef ME_MACH_VM_H
#define ME_MACH_VM_H

#import <mach/mach.h>
#import <mach/vm_types.h>
#import <mach/vm_region.h>
#import <mach/vm_prot.h>

// iOSのSDKヘッダ(<mach/mach_vm.h>)は `#error` でブロックされており、
// mach_vm_* 系のプロトタイプが宣言されない。ただし実行時のlibSystemには
// シンボル自体は存在するため、自プロセス(mach_task_self())操作専用として
// 必要な最小限のプロトタイプをここで手動宣言する。
__BEGIN_DECLS

kern_return_t mach_vm_region_recurse(vm_map_t target_task,
                                      mach_vm_address_t *address,
                                      mach_vm_size_t *size,
                                      natural_t *nesting_depth,
                                      vm_region_recurse_info_t info,
                                      mach_msg_type_number_t *infoCnt);

kern_return_t mach_vm_read(vm_map_t target_task,
                            mach_vm_address_t address,
                            mach_vm_size_t size,
                            vm_offset_t *data,
                            mach_msg_type_number_t *dataCnt);

kern_return_t mach_vm_write(vm_map_t target_task,
                             mach_vm_address_t address,
                             vm_offset_t data,
                             mach_msg_type_number_t dataCnt);

__END_DECLS

#endif /* ME_MACH_VM_H */
