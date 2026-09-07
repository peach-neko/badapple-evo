clear;clc;
disp('Setting.');
cores = input('Number of Processors be used at Parallel Computing ? ');
[filename,pathname] = uigetfile('*.avi','Select the video file','C:\Users\rnd\AppData\Roaming\PotPlayerMini64\Capture')
disp('Setting.');
disp('Waiting for user.');
%cores = str2num(cores);
disp('Done.');
pause(1);
clc;
disp('Loading files.');
xyloObj = VideoReader([pathname filename])
nFrames = xyloObj.NumberOfFrames;
vidHeight = xyloObj.Height;
vidWidth = xyloObj.Width;
vidFrameRate = xyloObj.FrameRate;
disp('Check Data.');
%if( vidHeight > 255 | vidWidth > 255 )
%errordlg('Video resolution is too high.It can not be use in 8bit MCU!','Warning');
%end
if( vidHeight > 800 || vidWidth > 600 )
errordlg('Video resolution is too high.It can not be use in this code!','Error');
error('end at line 23')
end
disp('Preallocate structure.');
% Preallocate movie structure.
mov(1:nFrames) = ...
    struct('cdata', zeros(vidHeight, vidWidth, 3, 'uint8'),...
           'colormap', []);
% imbinarize 返回二维逻辑矩阵 (vidHeight x vidWidth)
bwmov(1:nFrames) = struct('cdata', false(vidHeight, vidWidth), 'cal', []);
disp('Parallel Computing Enviornment initialization.');
close all;
delete(gcp('nocreate'));
parpool('local', cores);
disp('Processing frames.');
% Read one frame at a time.
for k = 1 : nFrames
    mov(k).cdata = read(xyloObj, k);
end
disp('Convert image to binary image.');
%L Convert image to binary image by thresholding.
parfor k = 1 : nFrames
    bwmov(k).cdata = imbinarize(im2gray(mov(k).cdata));
end
disp('Create edges of the image.');
%L [optional]finds edges using the Prewitt approximation to the derivative.
parfor k = 1 : nFrames
    %bwmov(k).cdata = edge(bwmov(k).cdata,'prewitt');
    bwmov(k).cdata = edge(bwmov(k).cdata,'sobel');
end
disp('Find bitrate per matrix.');
%L Convert matrix.
parfor k = 1 : nFrames
[B,~,~,~] = bwboundaries(bwmov(k).cdata);
% 计算所有边界点的总数（每个边界矩阵的行数 = 该边界的点数）
totalPoints = sum(cellfun(@(x) size(x, 1), B));
bwmov(k).cal = totalPoints;
end
cal = uint16([bwmov.cal]');    %uint16有溢出风险
maxcal = max(cal).*2; %注意这里改变最高采样数量 2倍并不适合大部分音频设备 效果不好时去掉*2
fill = [maxcal - cal ,floor(maxcal./cal),mod(maxcal,cal)];

disp('Data reorganization.');
%L Convert BWimage to single matrix.
filename = '\video.txt';
if(exist('pathname','var')) == 0
    pathname = uigetdir('','Select folder to SAVE data file') ;
end
writematrix([max(cal)*vidFrameRate, 0], [pathname filename], 'Delimiter', 'tab');
parfor k=1:nFrames
c = [];
cx = [];
data = [];
[B,~,~,~] = bwboundaries(bwmov(k).cdata);
    for ki=1:length(B)
        data = B{ki};
        data(:,1) = vidHeight - data(:,1);% Mirror
        data(:,2) = vidWidth - data(:,2);% Reverse
        data=data(:,[2 1]);% Rotate 90
        cx = [cx;data]; 
        %cx = [cs;vidHeight - B{ki}(:,2) , vidWidth - B{ki}(:,1)]   
    end
c = [c;cx];
    if fill(k,2)>1 && fill(k,2)< max(cal)
        for u = 1 : fill(k,2) - 1 
            c = [c;cx];
        end
    end
    if fill(k,3)>0 && fill(k,3)< max(cal)
        c = [c;cx(1:fill(k,3),:)];
    end
    bwmov(k).cal = uint16(c);    
end
disp('Create data matrix.');
if all(cellfun(@isempty, {bwmov.cal}))
    c = [];  % 全部为空，结果也为空
else
    c = vertcat(bwmov.cal);
end
disp('Parallel Computing Enviornment Stop.');
delete(gcp('nocreate'));
disp('Remove useless vars.');
clearvars f x y e k m u data B L N A ki kx col row cidx rndRow boundary calx colors cx h ans cores;
clearvars fill;
c_norm=[c(:,1).*0.79,c(:,2)];    %第一列的范围超过了255，把第一列归一化到0~255；第二列没超过，所以不需要操作    todo:自动归一化
c8=uint8(c_norm);
filename = 'example_8_192k_2.wav';
audiowrite(filename, c8, 192000, 'BitsPerSample', 8);
%disp('Files.');
%reply = input('Do you want a File? Y/N [N]: ', 's');
%if (isempty(reply))
%    reply = 'N';
%end
%if ( reply == 'Y' || reply == 'y')
%    writematrix(c, [pathname filename], 'Delimiter', 'tab', 'WriteMode', 'append');
%end
disp('Output.');
reply = input('Output Data via PC sound? Y/N [N]: ', 's');
if (isempty(reply))
    reply = 'N';
end
if ( reply == 'Y' || reply == 'y')
c = double(c);
cal = double(cal);
    soundsc(c,vidFrameRate*max(cal)*2,16);
%注意这里改变最高采样数量
end