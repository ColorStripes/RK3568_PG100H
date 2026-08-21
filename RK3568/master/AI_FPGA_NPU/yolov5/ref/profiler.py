import torch.profiler
from ppq import *
from ppq.api import *

sample_input = [torch.rand(1, 3, 244, 244) for i in range(32)]
ir = quantize_onnx_model(
    onnx_import_file="working/resnet18.onnx",
    calib_dataloader=sample_input,
    calib_steps=16,
    do_quantize=False,
    input_shapes=None,
    collate_fn=lambda x: x.to('cuda'))
executor = TorchExecutor(ir)

with torch.profiler,profile(
    schedule=torch.profiler.schedule(wait=2, warmup=2, active=6, repeat=1),
    on_trace_ready=torch.profiler.tensorboard_trace_handler(
        dir_name='working/performance/'),
    activities=[torch.profiler.ProfilerActivity.CPU,
                torch.profiler.ProfilerActivity.CUDA
                ],
    with_stack=True,
) as profiler:
    with torch_no_grad():
        for batch_idx in tqdm(range(16),
                              desc='Profiling ...'):
            executor.forward(sample_input[0].to('cuda'))
            profiler.step()