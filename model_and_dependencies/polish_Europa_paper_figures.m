function polish_Europa_paper_figures(output_dir,build_dir,mode)
% Layout-only second pass on saved editable figures; no numerical data changes.
if nargin<2
 root=fileparts(fileparts(mfilename('fullpath')));
 p=jsondecode(fileread(fullfile(root,'tmp','manuscript_figures_latest.json')));
 output_dir=p.output_dir;build_dir=p.build_dir;
end
if nargin<3,mode='all';end
files=dir(fullfile(output_dir,'0*.fig'));
if strcmp(mode,'field_only'),files=files(startsWith({files.name},'03_') | startsWith({files.name},'04_'));end
if strcmp(mode,'log_only'),files=files(startsWith({files.name},'06_') | startsWith({files.name},'07_'));end
for k=1:numel(files)
 stem=files(k).name(1:end-4);f=openfig(fullfile(files(k).folder,files(k).name),'invisible');
 if startsWith(stem,'01_')
  legends=findall(f,'Type','legend');
  for j=1:numel(legends)
   if numel(legends(j).String)>1,set(legends(j),'Box','on','Color','w','EdgeColor','none');end
  end
 elseif startsWith(stem,'02_')
  axes_list=findall(f,'Type','axes');
  for ax=axes_list'
   q=ax.Position;
   if q(1)<.5,ax.Position=[.085 q(2) .29 .32];else,ax.Position=[.59 q(2) .29 .32];end
  end
  bars=findall(f,'Type','colorbar');
  for cb=bars'
   q=cb.Position;
   if q(1)<.5,cb.Position=[.395 q(2) .018 .32];else,cb.Position=[.91 q(2) .018 .32];end
   cb.FontSize=10;cb.Label.FontSize=11;
  end
 elseif startsWith(stem,'03_') || startsWith(stem,'04_')
  delete(findall(f,'Type','colorbar'));
  axes_list=findall(f,'Type','axes');
  for ax=axes_list'
   if ax.Position(2)<.13,delete(ax);end
  end
  horizontal_scale(f,[.30 .115 .27 .014],[0 1],flipud(parula(256)),0:.2:1,'Melt fraction');
  horizontal_scale(f,[.68 .115 .25 .014],[100 273],bone(256),[100 150 200 250],'Temperature, K');
  boxes=findall(f,'Type','textboxshape');
  for t=boxes'
   q=t.Position;
   if q(2)<.04,t.Position=[.15 .435 .75 .028];t.FontSize=8.5;t.Margin=0;end
  end
 elseif startsWith(stem,'05_') || startsWith(stem,'06_') || startsWith(stem,'07_')
  axes_list=findall(f,'Type','axes');
  for ax=axes_list'
   if strcmp(ax.XScale,'log') && strcmp(ax.YAxisLocation,'left')
    limits=ax.XLim;powers=unique([ceil(log10(limits(1))):2:floor(log10(limits(2))) floor(log10(limits(2)))]);
    ax.XTick=10.^powers;
   end
  end
  labels=findall(f,'Type','text');
  for t=labels'
   if ischar(t.String) && startsWith(t.String,'Ongoing to ')
    t.Units='normalized';
    if startsWith(stem,'05_'),t.Position=[.35 .90 0];else,t.Position=[.06 .70 0];end
   end
  end
 end
font_objects=findall(f,'-property','FontName');set(font_objects,'FontName','Times New Roman');
drawnow;
print(f,fullfile(build_dir,'pages',[stem '.pdf']),'-dpdf','-painters');
print(f,fullfile(output_dir,[stem '.svg']),'-dsvg','-painters');
savefig(f,fullfile(output_dir,[stem '.fig']),'compact');close(f);
fprintf('LAYOUT_POLISHED %s\n',stem);
end
end

function horizontal_scale(f,position,limits,map,ticks,label)
ax=axes(f,'Position',position,'FontName','Times New Roman','FontSize',12);
image(ax,linspace(limits(1),limits(2),256),.5,reshape(map,1,256,3));
set(ax,'XLim',limits,'YLim',[0 1],'YDir','normal','YTick',[],'YColor','none', ...
 'XTick',ticks,'XAxisLocation','bottom','TickDir','out','Box','on','LineWidth',.5,'FontSize',12,'FontName','Times New Roman');
xlabel(ax,label,'FontSize',12);
end
